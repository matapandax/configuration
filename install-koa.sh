#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export OPENEDX_RELEASE=${OPENEDX_RELEASE:-open-release/koa.master}

cd "$REPO_ROOT"
"$REPO_ROOT/scripts/preflight-koa.sh"

if [[ ${1:-} == --preflight-only ]]; then
    exit 0
fi

echo "Stage 1/3: installing Open edX $OPENEDX_RELEASE"
"$REPO_ROOT/util/install/native.sh" "$@"

echo "Stage 2/3: installing Analytics API, Pipeline infrastructure, and Insights"
sudo -E ansible-playbook -c local \
    "$REPO_ROOT/playbooks/analytics_single.yml" \
    -i "localhost," \
    -e@"$REPO_ROOT/config.yml" \
    -e@"$REPO_ROOT/my-passwords.yml" \
    -e "EDX_PLATFORM_VERSION=$OPENEDX_RELEASE" \
    -e "ANALYTICS_API_VERSION=master" \
    -e "INSIGHTS_VERSION=master"

echo "Stage 3/3: finalizing Analytics Pipeline, Insights, Redis, and Celery"
sudo "$REPO_ROOT/scripts/post-install-koa-insights.sh"

echo "Open edX Koa and Insights installation completed"
