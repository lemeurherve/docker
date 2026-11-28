#!/usr/bin/env bash
set -euo pipefail

: "${JENKINS_VERSION:=}"

function sort-versions() {
    if [[ "$(uname)" == 'Darwin' ]]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

all_jenkins_versions="$(curl --disable --fail --silent --show-error --location \
	https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/maven-metadata.xml |
	grep '<version>.*</version>')"

latest_lts_version="$(echo "${all_jenkins_versions}" | grep -E -o '[0-9]\.[0-9]+\.[0-9]' | sort-versions | tail -n1)"
latest_weekly_version="$(echo "${all_jenkins_versions}" | grep -E -o '[0-9]\.[0-9]+' | sort-versions | tail -n1)"

latest_weekly="false"
if [[ "${JENKINS_VERSION}" == "${latest_weekly_version}" ]]; then
	latest_weekly="true"
fi

latest_lts="false"
if [[ "${JENKINS_VERSION}" == "${latest_lts_version}" ]]; then
	latest_lts="true"
fi

printf 'LATEST_WEEKLY=%s\n' "${latest_weekly}"
printf 'LATEST_LTS=%s\n' "${latest_lts}"
