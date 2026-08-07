# Portable Open edX Koa with Insights

This branch installs Open edX Koa and the legacy Insights stack from the
playbooks in this checkout. It includes the Ubuntu 20.04 compatibility fixes
and post-install steps validated on the reference server.

Koa, Python 2.7, and MongoDB 3.6 are end-of-life. Deploy them only on an
isolated host with restricted network access and plan an upgrade.

## Target server

- Fresh Ubuntu 20.04 x86_64
- At least 16 GB RAM
- At least 50 GB free disk; 100 GB is recommended
- Root access through `sudo`
- Working DNS and outbound HTTPS access

## Configure

```bash
cp config.example.yml config.yml
```

Replace every `example.com` hostname in `config.yml`, then generate unique
credentials:

```bash
OPENEDX_RELEASE=open-release/koa.master ./util/install/generate-passwords.sh
```

Do not copy `my-passwords.yml` between installations or commit it to Git.

## Install

```bash
./install-koa.sh --preflight-only
OPENEDX_RELEASE=open-release/koa.master ./install-koa.sh
```

The installer performs three stages:

1. LMS, Studio, databases, workers, and supporting Open edX services.
2. Analytics API, Hadoop/Hive/Sqoop infrastructure, and Insights.
3. Analytics Pipeline, report schemas, API account, Redis authentication,
   Celery restart, and the daily analytics timer.

## Verify

```bash
sudo /edx/bin/supervisorctl status
sudo systemctl status redis-server --no-pager
sudo systemctl status openedx-analytics-daily.timer --no-pager
sudo -u edxapp bash -lc 'source /edx/app/edxapp/edxapp_env && cd /edx/app/edxapp/edx-platform && celery -A lms.celery:APP inspect ping --timeout=8'
```

Insights panels remain empty until learner events exist and the analytics
pipeline has processed them.
