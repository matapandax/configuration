#!/usr/bin/env bash

set -uo pipefail

PIPELINE_CODE=/edx/app/analytics_pipeline/analytics_pipeline
PIPELINE_VENV=/edx/app/analytics_pipeline/venvs/analytics_pipeline
OVERRIDE_CONFIG=/edx/etc/edx-analytics-pipeline/koa-override.cfg
END_DATE=$(date -u +%F)
INTERVAL_START=$(date -u -d '7 days ago' +%F)
INTERVAL_END=$(date -u -d 'tomorrow' +%F)
status=0

cd "$PIPELINE_CODE" || exit 1
source "$PIPELINE_VENV/bin/activate"
export LUIGI_CONFIG_PATH=config/devstack.cfg

launch-task ImportEnrollmentsIntoMysql \
    --local-scheduler --workers 1 --n-reduce-tasks 1 \
    --interval-start "$INTERVAL_START" --interval-end "$INTERVAL_END" \
    --overwrite-n-days 7 --overwrite-hive --overwrite-mysql \
    --additional-config "$OVERRIDE_CONFIG" || status=$?

launch-task InsertToMysqlCourseActivityTask \
    --local-scheduler --workers 1 --n-reduce-tasks 1 \
    --end-date "$END_DATE" --weeks 1 \
    --overwrite-n-days 7 --overwrite-hive --overwrite-mysql \
    --additional-config "$OVERRIDE_CONFIG" || activity_status=$?

if [[ ${activity_status:-0} -ne 0 && ${activity_status:-0} -ne 30 ]]; then
    status=$activity_status
fi
exit "$status"
