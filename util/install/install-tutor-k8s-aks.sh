#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:?Set RESOURCE_GROUP to the Azure resource group name.}"
AKS_NAME="${AKS_NAME:?Set AKS_NAME to the AKS cluster name.}"
LMS_HOST="${LMS_HOST:?Set LMS_HOST to the public LMS hostname.}"
CMS_HOST="${CMS_HOST:?Set CMS_HOST to the public Studio hostname.}"
CONTACT_EMAIL="${CONTACT_EMAIL:?Set CONTACT_EMAIL for HTTPS certificate notices.}"
PLATFORM_NAME="${PLATFORM_NAME:-Open edX}"
MODE="${MODE:-prepare}"
TUTOR_PACKAGE_SPEC="${TUTOR_PACKAGE_SPEC:-tutor[full]>=21.0.0,<22.0.0}"
ENABLE_MINIO="${ENABLE_MINIO:-1}"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required. Install it, run az login, then retry." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to install Tutor." >&2
  exit 1
fi

az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_NAME}" \
  --overwrite-existing

python3 -m pip install --user --upgrade pip
python3 -m pip install --user "${TUTOR_PACKAGE_SPEC}"

export PATH="${HOME}/.local/bin:${PATH}"

tutor config save \
  --set "LMS_HOST=${LMS_HOST}" \
  --set "CMS_HOST=${CMS_HOST}" \
  --set "PLATFORM_NAME=${PLATFORM_NAME}" \
  --set "CONTACT_EMAIL=${CONTACT_EMAIL}" \
  --set "ENABLE_HTTPS=true"

if [ "${ENABLE_MINIO}" = "1" ]; then
  tutor plugins enable minio
  tutor config save
fi

case "${MODE}" in
  prepare)
    tutor k8s start caddy
    echo
    echo "Caddy load balancer requested. Wait for EXTERNAL-IP, then point DNS records to it:"
    kubectl --namespace openedx get services/caddy
    echo
    echo "After DNS resolves, run this script again with MODE=launch."
    ;;
  launch)
    tutor k8s launch --non-interactive
    tutor k8s status
    ;;
  status)
    tutor k8s status
    kubectl --namespace openedx get services/caddy
    ;;
  *)
    echo "Unknown MODE=${MODE}. Use prepare, launch, or status." >&2
    exit 1
    ;;
esac
