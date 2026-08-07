#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
errors=0

fail() {
    echo "ERROR: $*" >&2
    errors=$((errors + 1))
}

source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 20.04 ]] || \
    fail "Open edX Koa requires Ubuntu 20.04"

memory_mb=$(awk '/MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
(( memory_mb >= 15000 )) || fail "At least 16 GB RAM is required; found ${memory_mb} MB"

disk_mb=$(df -Pm "$REPO_ROOT" | awk 'NR == 2 {print $4}')
(( disk_mb >= 50000 )) || fail "At least 50 GB free disk is required; found ${disk_mb} MB"

[[ -r "$REPO_ROOT/config.yml" ]] || fail "Create config.yml from config.example.yml"
[[ -r "$REPO_ROOT/my-passwords.yml" ]] || fail "Run util/install/generate-passwords.sh"

if [[ -r "$REPO_ROOT/my-passwords.yml" ]]; then
    mode=$(stat -c %a "$REPO_ROOT/my-passwords.yml")
    [[ $mode == 600 ]] || fail "my-passwords.yml must have mode 600; found $mode"
fi

if (( errors > 0 )); then
    echo "Preflight failed with $errors error(s)." >&2
    exit 1
fi

python3 - "$REPO_ROOT/config.yml" "$REPO_ROOT/my-passwords.yml" <<'PY'
import sys
import yaml

with open(sys.argv[1]) as config_file:
    config = yaml.safe_load(config_file) or {}
with open(sys.argv[2]) as passwords_file:
    passwords = yaml.safe_load(passwords_file) or {}

required = {
    "config.yml": (config, [
        "EDXAPP_LMS_BASE", "EDXAPP_CMS_BASE",
        "EDXAPP_ANALYTICS_DASHBOARD_URL", "INSIGHTS_BASE_URL",
        "ANALYTICS_API_ENDPOINT",
    ]),
    "my-passwords.yml": (passwords, [
        "REDIS_PASSWORD", "EDXAPP_CELERY_PASSWORD",
        "ANALYTICS_API_AUTH_TOKEN", "ANALYTICS_API_USERS",
        "INSIGHTS_DATA_API_AUTH_TOKEN", "ANALYTICS_API_REPORTS_PASSWORD",
        "ANALYTICS_PIPELINE_OUTPUT_DATABASE_PASSWORD",
    ]),
}
for filename, (values, keys) in required.items():
    missing = [key for key in keys if not values.get(key)]
    if missing:
        raise SystemExit("{} is missing: {}".format(filename, ", ".join(missing)))

token = passwords["ANALYTICS_API_AUTH_TOKEN"]
if passwords["INSIGHTS_DATA_API_AUTH_TOKEN"] != token:
    raise SystemExit("Analytics API and Insights tokens must match")
if passwords["ANALYTICS_API_USERS"].get("insights") != token:
    raise SystemExit("The insights API user must use the shared analytics token")
PY

echo "Open edX Koa preflight passed"
