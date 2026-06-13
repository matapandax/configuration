#!/usr/bin/env bash
set -euo pipefail

LMS_HOST="${LMS_HOST:?Set LMS_HOST to the public LMS hostname.}"
CMS_HOST="${CMS_HOST:?Set CMS_HOST to the public Studio hostname.}"
CONTACT_EMAIL="${CONTACT_EMAIL:?Set CONTACT_EMAIL for HTTPS certificate notices.}"
PLATFORM_NAME="${PLATFORM_NAME:-Open edX}"
MODE="${MODE:-prepare}"
TUTOR_PACKAGE_SPEC="${TUTOR_PACKAGE_SPEC:-tutor[full]}"
ENABLE_MINIO="${ENABLE_MINIO:-1}"
ENABLE_MFE="${ENABLE_MFE:-1}"
MFE_HOST="${MFE_HOST:-apps.${LMS_HOST}}"
TUTOR_VENV="${TUTOR_VENV:-/opt/tutor-venv}"

install_system_dependencies() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y acl ca-certificates curl git gnupg libyaml-dev python3 python3-pip python3-venv

  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sudo sh
  fi

  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "${SUDO_USER:-$USER}" || true
  sudo setfacl -m "u:${USER}:rw" /var/run/docker.sock || true
}

install_tutor() {
  sudo python3 -m venv "${TUTOR_VENV}"
  sudo "${TUTOR_VENV}/bin/pip" install --upgrade pip wheel
  sudo "${TUTOR_VENV}/bin/pip" install --upgrade "${TUTOR_PACKAGE_SPEC}"
  sudo ln -sf "${TUTOR_VENV}/bin/tutor" /usr/local/bin/tutor
}

save_tutor_config() {
  tutor config save \
    --set "LMS_HOST=${LMS_HOST}" \
    --set "CMS_HOST=${CMS_HOST}" \
    --set "MFE_HOST=${MFE_HOST}" \
    --set "PLATFORM_NAME=${PLATFORM_NAME}" \
    --set "CONTACT_EMAIL=${CONTACT_EMAIL}" \
    --set "ENABLE_HTTPS=true"

  if [ "${ENABLE_MFE}" = "1" ]; then
    tutor plugins install mfe
    tutor plugins enable mfe
    tutor config save --set "MFE_HOST=${MFE_HOST}"
  fi

  if [ "${ENABLE_MINIO}" = "1" ]; then
    tutor plugins enable minio
    tutor config save
  fi
}

show_status() {
  echo
  echo "Tutor hostnames:"
  tutor config printvalue LMS_HOST
  tutor config printvalue CMS_HOST
  tutor config printvalue MFE_HOST
  echo
  tutor local status || true
}

install_system_dependencies
install_tutor
save_tutor_config

case "${MODE}" in
  prepare)
    tutor local start caddy
    echo
    echo "Caddy was started. Point Azure DNS records to the Load Balancer public IP, then rerun with MODE=launch."
    show_status
    ;;
  launch)
    tutor local launch --non-interactive
    show_status
    ;;
  status)
    show_status
    ;;
  *)
    echo "Unknown MODE=${MODE}. Use prepare, launch, or status." >&2
    exit 1
    ;;
esac
