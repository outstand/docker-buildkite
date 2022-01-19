# Buildkite Agent

## Usage

```sh
docker run --rm public.ecr.aws/a5k7g6j4/buildkite-agent:3 help

docker run --rm \
-v /etc/os-release:/etc/host-os-release:ro \
-v /var/lib/buildkite-agent:/var/lib/buildkite-agent \
-v /var/lib/buildkite:/var/lib/buildkite \
-v /var/run/docker.sock:/var/run/docker.sock \
public.ecr.aws/a5k7g6j4/buildkite-agent:3
```

## About

This image is based on https://hub.docker.com/r/buildkite/agent but adapted to run as a non-root user and in an selinux hardened environment (bottlerocket).

Additionally, we've added standard tools for ruby and rust along with the following:
- tini
- su-exec
- zsh
- jq
- rsync
- less
- zstd
- docker
- docker compose v2
- compose-switch
- git-lfs
- aws-cli v2
- hashicorp boundary
- standalone buildkit
- bundler
- buildkite/docker-ssh-env-config
