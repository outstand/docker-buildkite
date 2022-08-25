FROM buildkite/agent:3.38.0-ubuntu as agent
FROM outstand/tini as tini
FROM outstand/su-exec as su-exec

FROM buildpack-deps:bullseye
LABEL maintainer="Ryan Schlesinger <ryan@outstand.com>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=tini /sbin/tini /sbin/
COPY --from=su-exec /sbin/su-exec /sbin/

# COPIED FROM ruby:2.5.1-alpine3.7
# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
ENV PATH $GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"
# (BUNDLE_PATH = GEM_HOME, no need to mkdir/chown both)

RUN set -eux; \
      \
      groupadd -g 1000 --system ci; \
      useradd -u 1000 -g ci -ms /bin/bash --system ci; \
      groupadd -g 900 docker; \
      usermod -a -G docker ci; \
      apt-get update -y; \
      apt-get install -y --no-install-recommends \
        zsh \
        jq \
        ruby \
        ruby-bundler \
        rustc \
        cargo \
        apt-transport-https \
        gnupg-agent \
        software-properties-common \
        perl \
        openssh-client \
        rsync \
        less \
        zstd \
      ; \
      \
      apt-get clean; \
      rm -f /var/lib/apt/lists/*_*/; \
      \
      curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -; \
      add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"; \
      apt-get update -y; \
      apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
      ; \
      \
      apt-get clean; \
      rm -f /var/lib/apt/lists/*_*

# This is the last known-good version of compose.
ENV DOCKER_COMPOSE_VERSION 2.2.3
ENV COMPOSE_SWITCH_VERSION 1.0.4

RUN set -eux; \
      \
      mkdir -p /usr/local/lib/docker/cli-plugins; \
      curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose; \
      chmod +x /usr/local/lib/docker/cli-plugins/docker-compose; \
      curl -fL https://github.com/docker/compose-switch/releases/download/v${COMPOSE_SWITCH_VERSION}/docker-compose-linux-amd64 -o /usr/local/bin/compose-switch; \
      chmod +x /usr/local/bin/compose-switch; \
      update-alternatives --install /usr/local/bin/docker-compose docker-compose /usr/local/bin/compose-switch 99

RUN set -eux; \
      \
      echo 'source /etc/profile' > /home/ci/.bashrc; \
      echo 'source /etc/profile' > /home/ci/.bash_profile; \
      echo 'source /etc/profile' > /root/.bashrc; \
      echo 'source /etc/profile' > /root/.bash_profile; \
      echo 'export FIXUID=$(id -u) \n\
            export FIXGID=$(id -g)' > /etc/profile.d/fixuid.sh; \
      chown ci:ci /srv

ENV GIT_LFS_VERSION 3.2.0
ENV GIT_LFS_HASH d6730b8036d9d99f872752489a331995930fec17b61c87c7af1945c65a482a50
RUN set -eux; \
      \
      mkdir -p /tmp/build; \
	    cd /tmp/build; \
      \
      curl -sSL -o git-lfs.tgz https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-amd64-v${GIT_LFS_VERSION}.tar.gz; \
      echo "${GIT_LFS_HASH}  git-lfs.tgz" | sha256sum -c -; \
      tar -xzf git-lfs.tgz --strip-components=1; \
      cp git-lfs /usr/local/bin/; \
      \
      cd; \
      rm -rf /tmp/build; \
      \
      git lfs install --system

RUN set -eux; \
      \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
      unzip awscliv2.zip; \
      ./aws/install; \
      rm awscliv2.zip

RUN set -eux; \
      \
      curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -; \
      apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"; \
      apt-get update -y; \
      apt-get install -y --no-install-recommends \
        boundary \
      ; \
      \
      apt-get clean; \
      rm -f /var/lib/apt/lists/*_*/

ENV BUILDKIT_VERSION v0.10.3
RUN set -eux; \
      \
      cd /usr/local/bin; \
      wget -nv https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz; \
      tar --strip-components=1 -zxvf buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz bin/; \
      chmod +x buildctl buildkit-runc buildkitd; \
      rm -f buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz

USER ci

ENV BUNDLER_VERSION 2.3.21
RUN gem install bundler -v ${BUNDLER_VERSION} --force --no-document

USER root

ENV DOCKER_CLI_EXPERIMENTAL=enabled

ENV BUILDKITE_AGENT_CONFIG=/buildkite/buildkite-agent.cfg \
    PATH="/usr/local/bin:${PATH}"

RUN set -eux; \
      \
      mkdir -p /var/lib/buildkite/builds /buildkite/hooks /var/lib/buildkite/plugins; \
      curl -Lfs -o /usr/local/bin/ssh-env-config.sh https://raw.githubusercontent.com/buildkite/docker-ssh-env-config/master/ssh-env-config.sh; \
      chmod +x /usr/local/bin/ssh-env-config.sh; \
      chown -R ci:ci /var/lib/buildkite; \
      chown -R ci:ci /buildkite

COPY ./buildkite-agent.cfg /buildkite/buildkite-agent.cfg
COPY --from=agent /usr/local/bin/buildkite-agent /usr/local/bin/buildkite-agent
COPY hooks/pre-command /buildkite/hooks/

ENV BUILDKIT_PROGRESS plain

VOLUME /var/lib/buildkite
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
