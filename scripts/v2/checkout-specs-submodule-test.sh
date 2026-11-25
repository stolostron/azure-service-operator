#!/bin/bash
# Synthetic submodule cases for checkout-specs-submodule.sh.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
script="$root/scripts/v2/checkout-specs-submodule.sh"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=protocol.file.allow
export GIT_CONFIG_VALUE_0=always

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q --bare remote.git
git -C "$tmp/remote.git" symbolic-ref HEAD refs/heads/main
src=$tmp/src
mkdir -p "$src/specification/a"
git -C "$src" init -q -b main
git -C "$src" config user.email t@t
git -C "$src" config user.name t
printf 'one\n' > "$src/README.md"
printf 'spec\n' > "$src/specification/a/file.json"
git -C "$src" add .
git -C "$src" commit -q -m first
git -C "$src" push -q "$tmp/remote.git" HEAD:refs/heads/main
pin=$(git -C "$src" rev-parse HEAD)
printf 'two\n' > "$src/README.md"
git -C "$src" commit -q -am second
git -C "$src" push -q "$tmp/remote.git" HEAD:refs/heads/main
newer=$(git -C "$src" rev-parse HEAD)

make_super() {
  name=$1
  super=$tmp/$name
  mkdir -p "$super"
  git -C "$super" init -q -b main
  git -C "$super" config user.email t@t
  git -C "$super" config user.name t
  printf 'root\n' > "$super/README"
  git -C "$super" add README
  git -C "$super" commit -q -m root
  git -C "$super" submodule add -q --name azure-rest-api-specs "$tmp/remote.git" v2/specs/azure-rest-api-specs
  git -C "$super/v2/specs/azure-rest-api-specs" checkout -q "$pin"
  git -C "$super" add v2/specs/azure-rest-api-specs
  git -C "$super" config -f .gitmodules submodule.azure-rest-api-specs.update none
  git -C "$super" add .gitmodules
  git -C "$super" commit -q -m pin
}

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "expected [$2] got [$1] ($3)" >&2
    exit 1
  fi
}

# Empty index with HEAD already at the gitlink. submodule update leaves it empty.
make_super empty
repo=$tmp/empty
specs=$repo/v2/specs/azure-rest-api-specs
git -C "$specs" read-tree --empty
rm -f "$specs/README.md" "$specs/specification/a/file.json"
git -C "$repo" -c submodule.azure-rest-api-specs.update=checkout submodule update --init -- v2/specs/azure-rest-api-specs
assert_eq "$(git -C "$specs" ls-files | wc -l | tr -d ' ')" "0" "update should leave an empty index"
(cd "$repo" && "$script")
assert_eq "$(git -C "$specs" rev-parse HEAD)" "$pin" "restored HEAD"
test -f "$specs/README.md"
test -f "$specs/specification/a/file.json"
echo "empty index restored"

# A newer complete checkout, including a staged edit, is kept.
make_super staged
repo=$tmp/staged
specs=$repo/v2/specs/azure-rest-api-specs
git -C "$specs" fetch -q origin
git -C "$specs" checkout -q "$newer"
printf 'edit\n' >> "$specs/README.md"
git -C "$specs" add README.md
staged_blob=$(git -C "$specs" rev-parse :README.md)
(cd "$repo" && "$script")
assert_eq "$(git -C "$specs" rev-parse HEAD)" "$newer" "developer HEAD"
assert_eq "$(git -C "$specs" rev-parse :README.md)" "$staged_blob" "staged blob"
echo "staged change kept"

# A non-empty index that is missing a path is left unchanged and reported.
make_super partial
repo=$tmp/partial
specs=$repo/v2/specs/azure-rest-api-specs
git -C "$specs" rm -q --cached specification/a/file.json
set +e
(cd "$repo" && "$script")
status=$?
set -e
if [ "$status" -eq 0 ]; then
  echo "partial index should fail" >&2
  exit 1
fi
if git -C "$specs" ls-files --error-unmatch specification/a/file.json >/dev/null 2>&1; then
  echo "partial index was rewritten" >&2
  exit 1
fi
assert_eq "$(git -C "$specs" rev-parse HEAD)" "$pin" "partial HEAD"
echo "partial index preserved and reported"

# A recursive clone leaves the directory empty and generation must fill the gitlink.
make_super donor
git clone -q --recurse-submodules "$tmp/donor" "$tmp/cloned"
specs=$tmp/cloned/v2/specs/azure-rest-api-specs
test ! -e "$specs/.git"
(cd "$tmp/cloned" && "$script")
assert_eq "$(git -C "$specs" rev-parse HEAD)" "$pin" "cloned HEAD"
test -f "$specs/README.md"
echo "empty clone checked out"

echo "ok"
