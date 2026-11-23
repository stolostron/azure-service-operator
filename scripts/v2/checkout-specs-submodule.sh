#!/bin/bash
# Check out v2/specs/azure-rest-api-specs for code generation.
#
# update=none leaves a recursive clone empty, so generation has to fetch it.
# An existing complete checkout is kept, even when it is not the gitlink and
# even when it has staged changes. An empty index is not a staged change:
# git submodule update does nothing when HEAD is already the gitlink, so this
# script checks that commit out itself. If that still leaves files missing, it
# fails instead of letting generation read a partial tree.

set -eu

specs=v2/specs/azure-rest-api-specs

git_specs() {
  git -c safe.directory='*' -C "$specs" "$@"
}

index_missing_head_paths() {
  # Exit 0 when the index is missing paths that are in HEAD.
  # --quiet --diff-filter returns 1 only for deletions, not content edits.
  ! git_specs diff --cached --quiet --diff-filter=D HEAD
}

index_has_files() {
  git_specs ls-files | head -n 1 | grep -q .
}

if [ ! -e "$specs/.git" ] || ! git_specs rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  git -c safe.directory='*' -c submodule.azure-rest-api-specs.update=checkout submodule update --init --recursive -- "$specs"
fi

if index_missing_head_paths; then
  if index_has_files; then
    echo "azure-rest-api-specs is missing indexed files and has staged changes; leaving them in place" >&2
    exit 1
  fi

  # Empty index. submodule update will not fill it when HEAD is already the gitlink.
  gitlink=$(git -c safe.directory='*' rev-parse ":${specs}")
  git_specs checkout -f --detach "$gitlink"
  if index_missing_head_paths || ! index_has_files; then
    echo "azure-rest-api-specs checkout is incomplete and could not be restored" >&2
    exit 1
  fi
fi
