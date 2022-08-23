#!/usr/bin/env bash

set -e -u -o pipefail
shopt -s inherit_errexit

readarray -t PYTHON_VERSIONS < <(
    cat <<EOF
3.7
3.8
3.9
3.10
EOF
)

function _check_pyenv() {
    pyenv --version >/dev/null || (echo >&2 "pyenv is not installed" && exit 1)
}

function _get_python_version() {
    local VERSION
    VERSION=$1

    pyenv versions --bare |
        grep "^${VERSION}" |
        tail -n1
}

function _get_all_versions() {
    for VERSION in "${PYTHON_VERSIONS[@]}"; do
        _get_python_version "${VERSION}"
    done
}

function _run() {
    _check_pyenv

    local VERSIONS
    readarray -t VERSIONS < <(_get_all_versions)

    eval "$(pyenv init -)"
    pyenv shell "${VERSIONS[@]}"

    local TOX_BINARY
    local TOX_ENV_SUFFIX

    if [[ -n "${CI+1}" ]]; then
        # On CI, use last the python version from the version list
        TOX_BINARY=$(PYENV_VERSION=${VERSIONS[-1]} pyenv which tox)
        TOX_ENV_SUFFIX='ci'
    else
        # Locally, use tox from developer's venv
        TOX_BINARY=./venv/bin/tox
        TOX_ENV_SUFFIX='local'
    fi

    # Create a list of environments like pyXY-local,pyXZ-local or,
    # when running on CI, pyXY-ci,pyXZ-ci
    local TOX_ENV
    TOX_ENV=$(printf "%s\n" "${PYTHON_VERSIONS[@]}" |
        tr -d '.' |
        awk "{print \"py\" \$0 \"-${TOX_ENV_SUFFIX}\"}" |
        paste -s -d',' -)

    if [[ ! -f "${TOX_BINARY}" ]]; then
        echo >&2 "${TOX_BINARY} not found: venv doesn't exist or tox is not installed"
        exit 1
    fi

    "${TOX_BINARY}" -e "${TOX_ENV}" "$@"
}

_run "$@"
