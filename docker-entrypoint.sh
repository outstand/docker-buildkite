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

if [[ -d "$DIR" ]] ; then
  echo "Executing scripts in $DIR"
  /bin/run-parts --exit-on-error "$DIR"
fi

if [ "$1" = 'bash' ]; then
  exec /bin/bash
fi

exec /sbin/tini -g -- su-exec ci ssh-env-config.sh /usr/local/bin/buildkite-agent "$@"
