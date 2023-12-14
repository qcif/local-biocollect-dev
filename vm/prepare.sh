#!/usr/bin/env bash

set -euo pipefail

function log() {
  # log a message with the time, log level, and current script name
  local -r level="$1"
  local -r message="$2"
  echo >&2 -e "[${level}] ${message}"
}

function run_cmd() {
  if [[ $# -lt 1 ]]; then
    echo 'Must provide command to run.'
    return 1
  fi
  local -r cmd="$*"
  while true; do
    if $cmd; then
      break
    fi
    echo 'Command failed. Retrying in 5 seconds...'
    sleep 5
  done
}

log "INFO" "Get information from env vars."

if [[ -v FILE_OWNER ]]; then log "INFO" "FILE_OWNER is '${FILE_OWNER}'"; else log "ERROR" "Must set FILE_OWNER"; exit 1; fi
if [[ -v HOME_DIR ]]; then log "INFO" "HOME_DIR is '${HOME_DIR}'"; else log "ERROR" "Must set HOME_DIR"; exit 1; fi
if [[ -v SRC_DIR ]]; then log "INFO" "SRC_DIR is '${SRC_DIR}'"; else log "ERROR" "Must set SRC_DIR"; exit 1; fi
if [[ -v APT_URL ]]; then log "INFO" "APT_URL is '${APT_URL}'"; else log "ERROR" "Must set APT_URL"; exit 1; fi
if [[ -v ANSIBLE_VENV_DIR ]]; then log "INFO" "ANSIBLE_VENV_DIR is '${ANSIBLE_VENV_DIR}'"; else log "ERROR" "Must set ANSIBLE_VENV_DIR"; exit 1; fi
if [[ -v ANSIBLE_COLLECTIONS_DIR ]]; then log "INFO" "ANSIBLE_COLLECTIONS_DIR is '${ANSIBLE_COLLECTIONS_DIR}'"; else log "ERROR" "Must set ANSIBLE_COLLECTIONS_DIR"; exit 1; fi
if [[ -v VAGRANT_ARCHITECTURE ]]; then log "INFO" "VAGRANT_ARCHITECTURE is '${VAGRANT_ARCHITECTURE}'"; else log "ERROR" "Must set VAGRANT_ARCHITECTURE"; exit 1; fi
if [[ -v UBUNTU_RELEASE ]]; then log "INFO" "UBUNTU_RELEASE is '${UBUNTU_RELEASE}'"; else log "ERROR" "Must set UBUNTU_RELEASE"; exit 1; fi
if [[ -v PYTHON_VERSION ]]; then log "INFO" "PYTHON_VERSION is '${PYTHON_VERSION}'"; else log "ERROR" "Must set PYTHON_VERSION"; exit 1; fi
if [[ -v ANSIBLE_VERSION ]]; then log "INFO" "ANSIBLE_VERSION is '${ANSIBLE_VERSION}'"; else log "ERROR" "Must set ANSIBLE_VERSION"; exit 1; fi

log "INFO" "Ensure dirs exist and have correct ownership."

mkdir -p "${SRC_DIR}"
sudo chown -R "${FILE_OWNER}:${FILE_OWNER}" "${SRC_DIR}"

mkdir -p "${ANSIBLE_COLLECTIONS_DIR}"
sudo chown -R "${FILE_OWNER}:${FILE_OWNER}" "${ANSIBLE_COLLECTIONS_DIR}"

# update apt source to a local mirror to speed up the first apt update
if [[ -f /etc/apt/sources.list && ! $(grep "${APT_URL}" /etc/apt/sources.list) ]]; then
  log "INFO" "Set local ubuntu mirror and update apt."

  # update packages to get most recent ca-certificates
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq update

  # ensure ca-certificates is up to date so that https connections will work
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install ca-certificates

  cat << EOL | sudo tee /etc/apt/sources.list
# Ubuntu packages
# Officially supported: main restricted.
# Community supported: universe multiverse.
# Package updates are provided in the standard repository and the -updates repository.
deb ${APT_URL} ${UBUNTU_RELEASE} main restricted universe multiverse
deb ${APT_URL} ${UBUNTU_RELEASE}-updates main restricted universe multiverse

# Security updates - from mirror and direct from Ubuntu
deb ${APT_URL} ${UBUNTU_RELEASE}-security main restricted universe multiverse

# Back-ported package updates
deb ${APT_URL} ${UBUNTU_RELEASE}-backports main restricted universe multiverse
EOL

  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq update
fi

# update available apt packages
run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq update

# provide Python
if [[ ! -f "/etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-${UBUNTU_RELEASE}.list" ]]; then
  log "INFO" "Add deadsnakes ppa."

  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install software-properties-common python3-apt python-apt-common python3-packaging ca-certificates apt-transport-https
  sudo DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:deadsnakes/ppa
fi

# create a Python virtual env for ansible
if [[ ! -d "${ANSIBLE_VENV_DIR}" ]]; then
  log "INFO" "Install Python ${PYTHON_VERSION} and create ansible Python venv."

  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq update
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" "python${PYTHON_VERSION}-distutils"
  run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install libxml2-dev libxslt-dev zlib1g-dev libffi-dev

  sudo "python${PYTHON_VERSION}" -m venv "${ANSIBLE_VENV_DIR}"
  sudo chown -R "${FILE_OWNER}:${FILE_OWNER}" "${ANSIBLE_VENV_DIR}"
fi

run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq autoremove
run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq autoclean

log "INFO" "Install and update Python packages for ansible."

"${ANSIBLE_VENV_DIR}/bin/python" -m pip install -U pip
"${ANSIBLE_VENV_DIR}/bin/pip" install -U setuptools wheel
"${ANSIBLE_VENV_DIR}/bin/pip" install -U lxml "ansible-core==${ANSIBLE_VERSION}" ansible-lint

"${ANSIBLE_VENV_DIR}/bin/ansible-galaxy" collection install -p "${ANSIBLE_COLLECTIONS_DIR}" --upgrade \
  community.general ansible.posix \
  amazon.aws community.aws \
  community.mongodb community.mysql \
  community.docker ansible.netcommon \
  ansible.utils community.crypto

log "INFO" "Install database packages."

run_cmd sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install default-libmysqlclient-dev build-essential pkg-config
"${ANSIBLE_VENV_DIR}/bin/pip" install -U pymongo docker PyMySQL mysqlclient
