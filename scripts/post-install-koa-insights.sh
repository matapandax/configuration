#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PIPELINE_ROOT=/edx/app/analytics_pipeline
PIPELINE_CODE="$PIPELINE_ROOT/analytics_pipeline"
PIPELINE_VENV="$PIPELINE_ROOT/venvs/analytics_pipeline"
PIPELINE_COMMIT=a32acf0e51bc332c333b0745acfef663f404c307
ANALYTICS_API_ROOT=/edx/app/analytics_api/analytics_api
ANALYTICS_API_VENV=/edx/app/analytics_api/venvs/analytics_api

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo" >&2
    exit 1
fi

for path in /edx/etc/lms.yml /edx/etc/analytics_api.yml /edx/etc/insights.yml; do
    [[ -f "$path" ]] || { echo "Missing $path; run the playbooks first" >&2; exit 1; }
done

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    build-essential git libffi-dev libmysqlclient-dev libpq-dev libssl-dev \
    libxml2-dev libxslt1-dev python2.7 python2.7-dev virtualenv

id hadoop >/dev/null 2>&1 || { echo "The hadoop account is missing" >&2; exit 1; }
install -d -o hadoop -g hadoop "$PIPELINE_ROOT" "$PIPELINE_ROOT/venvs"

if [[ ! -d "$PIPELINE_CODE/.git" ]]; then
    sudo -u hadoop git clone --branch open-release/koa.3 \
        https://github.com/openedx/edx-analytics-pipeline.git "$PIPELINE_CODE"
else
    [[ -z $(sudo -u hadoop git -C "$PIPELINE_CODE" status --porcelain) ]] || {
        echo "$PIPELINE_CODE has local changes; refusing to overwrite" >&2
        exit 1
    }
    sudo -u hadoop git -C "$PIPELINE_CODE" fetch origin open-release/koa.3
fi
sudo -u hadoop git -C "$PIPELINE_CODE" checkout "$PIPELINE_COMMIT"

if [[ ! -x "$PIPELINE_VENV/bin/python" ]]; then
    sudo -u hadoop virtualenv --python=/usr/bin/python2.7 "$PIPELINE_VENV"
fi

requirements_file=$(mktemp)
cleanup_file() { rm -f "$requirements_file"; }
trap cleanup_file EXIT
grep -v '^psycopg2==' "$PIPELINE_CODE/requirements/default.txt" > "$requirements_file"

sudo -u hadoop "$PIPELINE_VENV/bin/pip" install -r "$PIPELINE_CODE/requirements/pip.txt"
sudo -u hadoop "$PIPELINE_VENV/bin/pip" install -r "$requirements_file"
sudo -u hadoop "$PIPELINE_VENV/bin/pip" install \
    https://cdn.mysql.com/archives/mysql-connector-python-1.2/mysql-connector-python-1.2.2.zip \
    psycopg2-binary==2.8.6
sudo -u hadoop "$PIPELINE_VENV/bin/pip" install --no-deps -e "$PIPELINE_CODE"

reports_user=$(python3 -c 'import yaml; print(yaml.safe_load(open("/edx/etc/analytics_api.yml"))["DATABASES"]["reports"]["USER"])')
[[ "$reports_user" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Unsafe reports user" >&2; exit 1; }

cleanup_grant() {
    mysql -e "REVOKE CREATE, ALTER, INDEX ON reports.* FROM '$reports_user'@'localhost';" 2>/dev/null || true
    cleanup_file
}
trap cleanup_grant EXIT
mysql -e "GRANT CREATE, ALTER, INDEX ON reports.* TO '$reports_user'@'localhost';"
sudo -u analytics_api bash -c \
    "cd '$ANALYTICS_API_ROOT' && source /edx/app/analytics_api/analytics_api_env && '$ANALYTICS_API_VENV/bin/python' manage.py shell < '$REPO_ROOT/scripts/bootstrap_insights.py'"
cleanup_grant
trap - EXIT

redis_password=$(python3 -c 'import yaml; print(yaml.safe_load(open("/edx/etc/lms.yml"))["CELERY_BROKER_PASSWORD"])')
[[ -n "$redis_password" ]] || { echo "CELERY_BROKER_PASSWORD is empty" >&2; exit 1; }
if redis-cli PING 2>/dev/null | grep -qx PONG; then
    redis-cli CONFIG SET requirepass "$redis_password"
else
    REDISCLI_AUTH="$redis_password" redis-cli PING | grep -qx PONG
fi
REDISCLI_AUTH="$redis_password" redis-cli CONFIG REWRITE
systemctl restart redis-server
REDISCLI_AUTH="$redis_password" redis-cli PING | grep -qx PONG

/edx/bin/supervisorctl restart 'edxapp_worker:*'
/edx/bin/supervisorctl restart analytics_api insights

install -d -o hadoop -g hadoop -m 0755 /edx/etc/edx-analytics-pipeline
install -o hadoop -g hadoop -m 0644 "$REPO_ROOT/analytics-pipeline-override.cfg" \
    /edx/etc/edx-analytics-pipeline/koa-override.cfg
install -o root -g root -m 0755 "$REPO_ROOT/scripts/run-analytics-daily.sh" \
    /edx/bin/run-analytics-daily
install -o root -g root -m 0644 "$REPO_ROOT/systemd/openedx-analytics-daily.service" \
    /etc/systemd/system/openedx-analytics-daily.service
install -o root -g root -m 0644 "$REPO_ROOT/systemd/openedx-analytics-daily.timer" \
    /etc/systemd/system/openedx-analytics-daily.timer
systemctl daemon-reload
systemctl enable --now openedx-analytics-daily.timer

echo "Koa Insights post-install completed successfully"
