# syntax = docker/dockerfile:1.4-labs

ARG PYTHON_VERSION_37=3.7.13
ARG PYTHON_VERSION_38=3.8.13
ARG PYTHON_VERSION_39=3.9.13
ARG PYTHON_VERSION_310=3.10.4

FROM ubuntu:20.04 as pyenv-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get update && \
    apt-get install -y \
      make \
      build-essential \
      libssl-dev \
      zlib1g-dev \
      libbz2-dev \
      libreadline-dev \
      libsqlite3-dev \
      wget \
      curl \
      libncursesw5-dev \
      xz-utils \
      libxml2-dev \
      libxmlsec1-dev \
      libffi-dev \
      liblzma-dev && \
    rm -rf /var/lib/apt/lists/*

ARG PYENV_DIST_VERSION=2.3.1
RUN wget https://github.com/pyenv/pyenv/archive/refs/tags/v${PYENV_DIST_VERSION}.tar.gz -O \
      /opt/pyenv-${PYENV_DIST_VERSION}.tar.gz && \
    cd /opt && \
    tar xzvf pyenv-${PYENV_DIST_VERSION}.tar.gz && \
    mv pyenv-${PYENV_DIST_VERSION} pyenv

ARG PYTHON_VERSION_37
ARG PYTHON_VERSION_38
ARG PYTHON_VERSION_39
ARG PYTHON_VERSION_310

ENV PYENV_ROOT=/opt/pyenv-root
RUN /opt/pyenv/bin/pyenv install ${PYTHON_VERSION_37} && \
    /opt/pyenv/bin/pyenv install ${PYTHON_VERSION_38} && \
    /opt/pyenv/bin/pyenv install ${PYTHON_VERSION_39} && \
    /opt/pyenv/bin/pyenv install ${PYTHON_VERSION_310} && \
    /opt/pyenv/bin/pyenv global \
      ${PYTHON_VERSION_37} \
      ${PYTHON_VERSION_38} \
      ${PYTHON_VERSION_39} \
      ${PYTHON_VERSION_310}

ARG TASKFILE_VERSION=3.13.0
RUN wget https://github.com/go-task/task/releases/download/v${TASKFILE_VERSION}/task_linux_amd64.deb -O \
      /opt/task_linux_amd64.deb

FROM ubuntu:20.04 as test-runner

ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get update && \
    apt-get install -y \
      git \
      libssl1.1 \
      zlib1g \
      bzip2 \
      libreadline8 \
      libsqlite3-0 \
      libncursesw5 \
      libxml2 \
      libxmlsec1 \
      libffi7 \
      liblzma5 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=pyenv-builder /opt/task_linux_amd64.deb /opt/
RUN apt install -y /opt/task_linux_amd64.deb && \
    rm /opt/task_linux_amd64.deb

ARG JENKINS_GID=2001
ARG JENKINS_UID=2001

RUN groupadd \
      --gid ${JENKINS_GID} jenkins && \
    useradd \
      --gid ${JENKINS_UID} \
      --uid ${JENKINS_UID} \
      --create-home \
      jenkins && \
    chown jenkins:jenkins /opt

USER jenkins

COPY --chown=jenkins:jenkins --from=pyenv-builder /opt/pyenv /opt/pyenv
ENV PATH=/opt/pyenv/bin:${PATH}

COPY --chown=jenkins:jenkins --from=pyenv-builder /opt/pyenv-root /opt/pyenv-root
ENV PYENV_ROOT=/opt/pyenv-root
ENV PATH=/opt/pyenv-root/shims:${PATH}

ARG PYTHON_VERSION_37
ARG PYTHON_VERSION_38
ARG PYTHON_VERSION_39
ARG PYTHON_VERSION_310

COPY requirements/dev.requirements.txt requirements/test.requirements.txt /opt/
RUN <<EOF
set -e -u -x

for VERSION in \
  ${PYTHON_VERSION_37} \
  ${PYTHON_VERSION_38} \
  ${PYTHON_VERSION_39} \
  ${PYTHON_VERSION_310}; do
  PYENV_VERSION=${VERSION} pyenv exec pip3 install \
    -r /opt/dev.requirements.txt \
    -r /opt/test.requirements.txt
done
EOF
