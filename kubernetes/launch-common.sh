#!/bin/bash -e
# shellcheck disable=SC2034
GIT_ROOT=$(git rev-parse --show-toplevel)

# Make sure we don't miss any changes
if [ "$(git status --porcelain --untracked-files=no | wc -l)" -gt 0 ]; then
    echo "Git repo is dirty, aborting" 1>&2
    exit 1
fi

# Maybe build and push new Docker images
python "$GIT_ROOT"/kubernetes/update_images.py --image cpp
# Load the env variables just created by update_images.py
# This line is weird because ShellCheck wants us to put double quotes around the
# $() context but this changes the behavior to something we don't want
# shellcheck disable=SC2046
export $(grep -v '^#' "$GIT_ROOT"/kubernetes/active-images.env | xargs)

if [ -n "${USE_WEKA}" ]; then
  export VOLUME_FLAGS="--volume-name go-attack --volume-mount /shared"
else
  export VOLUME_FLAGS="--shared-host-dir /nas/ucb/k8/go-attack --shared-host-dir-mount /shared"
fi