#!/bin/bash
set -euo pipefail

DIR=/docker-entrypoint.d

chown_r_dir() {
  dir=$1
  if [[ -d ${dir} ]] && [[ "$(stat -c %u:%g ${dir})" != "1000:1000" ]]; then
    echo chown -R $dir
    chown -R ci:ci $dir
  fi
}

chown_r_dir /var/lib/buildkite
mkdir -p /var/lib/buildkite-agent
chown_r_dir /var/lib/buildkite-agent

if [[ ! -x /var/lib/buildkite-agent/buildkite-agent ]]; then
  cp /usr/local/bin/buildkite-agent /var/lib/buildkite-agent/buildkite-agent
  chmod +x /var/lib/buildkite-agent/buildkite-agent
fi

if [[ -d "$DIR" ]] ; then
  echo "Executing scripts in $DIR"
  /bin/run-parts --exit-on-error "$DIR"
fi

if [ "$1" = 'bash' ]; then
  exec /bin/bash
fi

tags=()

if [ -n "${ECS_CONTAINER_METADATA_URI_V4:-}" ]; then
  task_id=$(curl -fs ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r '.TaskARN | split("/") | last')
  tags+=("ecs:task_id=${task_id}")
fi

# Extracts params based on https://www.freedesktop.org/software/systemd/man/os-release.html
host_os_release_param() {
  local param="$1"

  echo $(cat /etc/host-os-release | grep "^${param}=" | cut -d = -f 2 | tr -d '"')
}

if [ -f /etc/host-os-release ]; then
  os_id=$(host_os_release_param "ID")
  if [ -n "$os_id" ]; then
    tags+=("host:os_id=${os_id}")
  fi

  os_version=$(host_os_release_param "VERSION_ID")
  if [ -n "$os_version" ]; then
    tags+=("host:os_version=${os_version}")
  fi
fi

if [[ ${#tags[@]} -gt 0 ]] ; then
  export BUILDKITE_AGENT_TAGS="${tags[*]}"
  echo "Adding tags: ${BUILDKITE_AGENT_TAGS}"
fi

exec /sbin/tini -g -- su-exec ci ssh-env-config.sh /usr/local/bin/buildkite-agent "$@"
