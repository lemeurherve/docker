#!/bin/bash -eu

# Publish any versions of the docker image not yet pushed to ${JENKINS_REPO}
# Arguments:
#   -n dry run, do not build or publish images
#   -d debug

: "${JENKINS_VERSION:?Variable \$JENKINS_VERSION not set or empty.}"
: "${LATEST_WEEKLY:?Variable \$LATEST_WEEKLY not set or empty.}"
: "${LATEST_LTS:?Variable \$LATEST_LTS not set or empty.}"

set -eu -o pipefail

: "${DOCKERHUB_ORGANISATION:=jenkins}"
: "${DOCKERHUB_REPO:=jenkins}"
: "${BAKE_TARGET:=linux}"

export JENKINS_REPO="${DOCKERHUB_ORGANISATION}/${DOCKERHUB_REPO}"

function sort-versions() {
    if [ "$(uname)" == 'Darwin' ]; then
        gsort --version-sort
    else
        sort --version-sort
    fi
}

# Process arguments
dry_run=false
debug=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case "${key}" in
        -n)
        dry_run=true
        ;;
        -d)
        debug=true
        ;;
        *)
        echo "ERROR: Unknown option: ${key}"
        exit 1
        ;;
    esac
    shift
done


if [[ "${debug}" = true ]]; then
    echo "Debug mode enabled"
    set -x
fi

if [[ "${dry_run}" = true ]]; then
    echo "Dry run, will not publish images"
fi

build_opts=("--pull")
metadata_suffix="publish"
if test "${dry_run}" == "true"; then
    build_opts+=("--set=*.output=type=cacheonly")
    metadata_suffix="dry-run"
else
    build_opts+=("--push")
fi

# Save build result metadata
mkdir -p target
BUILD_METADATA_PATH="target/build-result-metadata_${BAKE_TARGET}_${metadata_suffix}.json"
bake_common_opts=("--file=docker-bake.hcl")
build_opts+=("--metadata-file=${BUILD_METADATA_PATH}")

COMMIT_SHA=$(git rev-parse HEAD)
export COMMIT_SHA JENKINS_VERSION LATEST_WEEKLY LATEST_LTS BUILD_METADATA_PATH

cat <<EOF
Using the following settings:
* JENKINS_REPO: ${JENKINS_REPO}
* JENKINS_VERSION: ${JENKINS_VERSION}
* COMMIT_SHA: ${COMMIT_SHA}
* LATEST_WEEKLY: ${LATEST_WEEKLY}
* LATEST_LTS: ${LATEST_LTS}
* BUILD_METADATA_PATH: ${BUILD_METADATA_PATH}
* BAKE_TARGET: ${BAKE_TARGET}
* BAKE OPTIONS:
$(printf '  %s\n' "${build_opts[@]}" "${bake_common_opts[@]}")
EOF

echo '* RESOLVED BAKE CONFIG:'
docker buildx bake "${bake_common_opts[@]}" --progress=quiet --print "${BAKE_TARGET}"

if [[ "${CI:-false}" == "false" ]]; then
  read -rp "Confirm? [y/N] " answer

  if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
      exit 0
  fi
fi

docker buildx bake "${bake_common_opts[@]}" "${build_opts[@]}" "${BAKE_TARGET}"
