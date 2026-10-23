#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# Migrate HCP resources embedded in CAPZ AROCluster, AROControlPlane, and
# AROMachinePool objects to the public 2026 API. Prints a plan unless --apply
# is passed. The Kubernetes storage version is a separate migration.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: migrate-hcp-original-version.sh --context CONTEXT [--namespace NAMESPACE] [--apply]

The default is a read-only plan across all namespaces. --apply updates each
CAPZ spec.resources entry and then writes its HCP child through the public
v20260901preview API, changing the child's stored spec.originalVersion.
Clusters without a VNet integration subnet are set to observe-delete before
their API version changes. They receive a clearly marked, synthetic subnet
reference to satisfy the 2026 schema. ASO must never send this reference to
Azure. The policy still permits ARM DELETE when the HCP object is deleted.

Requires oc and jq. Run with the transitional ASO build that serves the 2024,
2025, and 2026 HCP API versions.
EOF
}

context=""
namespace=""
apply=false
while (($#)); do
  case "$1" in
    --context) context="${2:?--context requires a value}"; shift 2 ;;
    --namespace) namespace="${2:?--namespace requires a value}"; shift 2 ;;
    --apply) apply=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$context" ]] || { usage >&2; exit 2; }
command -v oc >/dev/null
command -v jq >/dev/null

ocx() { oc --context "$context" "$@"; }

group="redhatopenshift.azure.com"
target="v20260901preview"
target_storage="${target}storage"
declare -A plural=(
  [HcpOpenShiftCluster]=hcpopenshiftclusters
  [HcpOpenShiftClustersNodePool]=hcpopenshiftclustersnodepools
  [HcpOpenShiftClustersExternalAuth]=hcpopenshiftclustersexternalauths
)

is_legacy_swift() {
  local kind="$1" ns="$2" child="$3" owner owner_resource
  if [[ "$kind" == HcpOpenShiftCluster ]]; then
    owner="$child"
  else
    owner_resource="$(jq -r '.spec.owner.name // empty' <<<"$child")"
    [[ -n "$owner_resource" ]] || {
      echo "Cannot determine HCP cluster owner for $kind in $ns" >&2
      return 1
    }
    owner="$(ocx get "hcpopenshiftclusters.${target_storage}.${group}" -n "$ns" "$owner_resource" -o json)"
  fi
  if jq -e '.spec.properties.platform.vnetIntegrationSubnetReference != null' <<<"$owner" >/dev/null; then
    echo false
  else
    echo true
  fi
}

# The target must be the active storage version and its public version must be
# served. A GET at a public API version alone does not prove an object's actual
# storage encoding or its original ARM API version.
for kind in "${!plural[@]}"; do
  crd="${plural[$kind]}.${group}"
  ocx get crd "$crd" -o json | jq -e --arg public "$target" --arg storage "$target_storage" '
    any(.spec.versions[]; .name == $public and .served == true and .storage == false) and
    any(.spec.versions[]; .name == $storage and .storage == true)
  ' >/dev/null || { echo "CRD $crd does not serve $target with $target_storage as storage" >&2; exit 1; }
done

scope=(-A)
[[ -z "$namespace" ]] || scope=(-n "$namespace")
rows=()
for parent_type in arocluster arocontrolplane aromachinepool; do
  parents="$(ocx get "$parent_type" "${scope[@]}" -o json)"
  mapfile -t found < <(jq -r --arg parent "$parent_type" --arg group "$group" '
    .items[] as $owner |
    ($owner.spec.resources // [] | to_entries[]) |
    select((.value.apiVersion // "") | startswith($group + "/")) |
    select(.value.kind == "HcpOpenShiftCluster" or
           .value.kind == "HcpOpenShiftClustersNodePool" or
           .value.kind == "HcpOpenShiftClustersExternalAuth") |
    [$parent, $owner.metadata.namespace, $owner.metadata.name,
     (.key | tostring), .value.kind, .value.metadata.name, .value.apiVersion,
     (.value.metadata.annotations["serviceoperator.azure.com/reconcile-policy"] // "manage")] | @tsv
  ' <<<"$parents")
  rows+=("${found[@]}")
done

declare -A seen=()
pending=0
for row in "${rows[@]}"; do
  IFS=$'\t' read -r parent_type ns parent_name index kind child_name source_version source_policy <<<"$row"
  [[ -n "$ns" && -n "$parent_name" && -n "$child_name" ]] || {
    echo "Invalid CAPZ HCP resource entry: $row" >&2; exit 1;
  }
  key="$ns/$kind/$child_name"
  [[ -z "${seen[$key]+x}" ]] || { echo "Duplicate CAPZ owner for $key" >&2; exit 1; }
  seen[$key]=1
  child_resource="${plural[$kind]}.${target_storage}.${group}"
  child="$(ocx get "$child_resource" -n "$ns" "$child_name" -o json)"
  original="$(jq -r '.spec.originalVersion // empty' <<<"$child")"
  [[ -n "$original" ]] || { echo "Missing spec.originalVersion on $key" >&2; exit 1; }
  policy="$(jq -r '.metadata.annotations["serviceoperator.azure.com/reconcile-policy"] // "manage"' <<<"$child")"
  legacy="$(is_legacy_swift "$kind" "$ns" "$child")"
  action=migrate
  if [[ "$source_version" == "$group/$target" && "$original" == "$target" ]] &&
     { [[ "$legacy" == false ]] || { [[ "$policy" == observe-delete ]] &&
                                   [[ "$source_policy" == observe-delete ]]; }; }; then
    action=already-current
  else
    ((pending+=1))
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$parent_type/$ns/$parent_name" "$kind/$child_name" "$source_version" \
    "$original" "$group/$target" "$policy" "legacy=$legacy" "$action"
done

if ! $apply; then
  printf 'HCP resources: %d; pending: %d. No changes made; pass --apply to migrate.\n' "${#rows[@]}" "$pending"
  exit 0
fi

for row in "${rows[@]}"; do
  IFS=$'\t' read -r parent_type ns parent_name index kind child_name source_version source_policy <<<"$row"
  child_resource="${plural[$kind]}.${target_storage}.${group}"
  public_resource="${plural[$kind]}.${target}.${group}"
  child="$(ocx get "$child_resource" -n "$ns" "$child_name" -o json)"
  original="$(jq -r '.spec.originalVersion' <<<"$child")"
  legacy="$(is_legacy_swift "$kind" "$ns" "$child")"
  child_policy="$(jq -r '.metadata.annotations["serviceoperator.azure.com/reconcile-policy"] // "manage"' <<<"$child")"
  if [[ "$source_version" == "$group/$target" && "$original" == "$target" ]] &&
     { [[ "$legacy" == false ]] || { [[ "$child_policy" == observe-delete ]] &&
                                   [[ "$source_policy" == observe-delete ]]; }; }; then
    printf 'Already current %s/%s\n' "$ns" "$child_name"
    continue
  fi
  placeholder=""
  if $legacy && [[ "$kind" == HcpOpenShiftCluster ]] &&
     { [[ "$source_version" != "$group/$target" ]] || [[ "$original" != "$target" ]]; }; then
    arm_id="$(jq -r '.status.id // empty' <<<"$child")"
    if [[ "$arm_id" =~ ^(/subscriptions/[^/]+/resource[Gg]roups/[^/]+)/providers/ ]]; then
      placeholder="${BASH_REMATCH[1]}/providers/Microsoft.Network/virtualNetworks/aso-legacy-swift-placeholder/subnets/aso-legacy-swift-placeholder"
    else
      echo "Cannot derive placeholder scope from ARM status ID for $ns/$child_name" >&2
      exit 1
    fi
  fi

  child_patch=""
  if [[ "$original" != "$target" ]] || [[ -n "$placeholder" ]]; then
    azure_name="$(jq -r '.spec.azureName // empty' <<<"$child")"
    [[ -n "$azure_name" ]] || { echo "Missing spec.azureName on $ns/$child_name" >&2; exit 1; }
    child_patch="$(jq -nc --arg name "$azure_name" --arg placeholder "$placeholder" '
      [{op:"test",path:"/spec/azureName",value:$name}]
      + (if $placeholder == "" then [] else
           [{op:"add",path:"/spec/properties/platform/vnetIntegrationSubnetReference",
             value:{armId:$placeholder}}] end)
      + [{op:"replace",path:"/spec/azureName",value:$name}]
    ')"
    # Validate the public API write before changing either CAPZ or the child.
    ocx patch "$public_resource" -n "$ns" "$child_name" --type=json \
      --dry-run=server -p "$child_patch" >/dev/null
  fi

  if $legacy; then
    # Set the child policy before changing CAPZ's source. Reconciliation can
    # begin immediately after the parent patch.
    ocx annotate "$child_resource" -n "$ns" "$child_name" \
      serviceoperator.azure.com/reconcile-policy=observe-delete --overwrite >/dev/null
    if [[ -n "$placeholder" ]]; then
      ocx annotate "$child_resource" -n "$ns" "$child_name" \
        serviceoperator.azure.com/legacy-swift-placeholder=true --overwrite >/dev/null
    fi
  fi

  parent="$(ocx get "$parent_type" -n "$ns" "$parent_name" -o json)"
  current_source="$(jq -r --argjson i "$index" '.spec.resources[$i].apiVersion' <<<"$parent")"
  [[ "$current_source" == "$source_version" ]] || {
    echo "CAPZ source changed during migration: $parent_type/$ns/$parent_name index $index" >&2; exit 1;
  }
  current_annotations="$(jq -c --argjson i "$index" '.spec.resources[$i].metadata.annotations // {}' <<<"$parent")"
  source_policy="$(jq -r '."serviceoperator.azure.com/reconcile-policy" // "manage"' <<<"$current_annotations")"
  source_marker="$(jq -r '."serviceoperator.azure.com/legacy-swift-placeholder" // "false"' <<<"$current_annotations")"
  source_placeholder="$(jq -r --argjson i "$index" '.spec.resources[$i].spec.properties.platform.vnetIntegrationSubnetReference.armId // empty' <<<"$parent")"
  if [[ "$current_source" != "$group/$target" ]] ||
     { $legacy && [[ "$source_policy" != observe-delete ]]; } ||
     { [[ -n "$placeholder" ]] && { [[ "$source_marker" != true ]] ||
                                    [[ "$source_placeholder" != "$placeholder" ]]; }; }; then
    patch="$(jq -nc --arg rv "$(jq -r '.metadata.resourceVersion' <<<"$parent")" \
      --arg old "$current_source" --arg new "$group/$target" --argjson i "$index" \
      --argjson annotations "$current_annotations" --argjson legacy "$legacy" \
      --arg placeholder "$placeholder" '
      ("/spec/resources/" + ($i | tostring)) as $path |
      [{op:"test",path:"/metadata/resourceVersion",value:$rv},
       {op:"test",path:($path + "/apiVersion"),value:$old}]
      + (if $old == $new then [] else [{op:"replace",path:($path + "/apiVersion"),value:$new}] end)
      + (if $legacy and $annotations["serviceoperator.azure.com/reconcile-policy"] != "observe-delete"
         then [{op:"add",path:($path + "/metadata/annotations"),
                value:($annotations + {"serviceoperator.azure.com/reconcile-policy":"observe-delete"})}]
         else [] end)
      + (if $placeholder != "" then
           [{op:"add",path:($path + "/metadata/annotations/serviceoperator.azure.com~1legacy-swift-placeholder"),value:"true"},
            {op:"add",path:($path + "/spec/properties/platform/vnetIntegrationSubnetReference"),
             value:{armId:$placeholder}}]
         else [] end)
    ' )"
    ocx patch "$parent_type" -n "$ns" "$parent_name" --type=json -p "$patch" >/dev/null
  fi

  if [[ -n "$child_patch" ]]; then
    # This is deliberately a same-value write through the public API. ASO's
    # conversion webhook sets the hidden storage spec.originalVersion to the
    # public version used for this write.
    ocx patch "$public_resource" -n "$ns" "$child_name" --type=json -p "$child_patch" >/dev/null
  fi

  child="$(ocx get "$child_resource" -n "$ns" "$child_name" -o json)"
  actual="$(jq -r '.spec.originalVersion' <<<"$child")"
  [[ "$actual" == "$target" ]] || {
    echo "Migration failed for $ns/$child_name: originalVersion=$actual" >&2; exit 1;
  }
  printf 'Migrated %s/%s: originalVersion=%s\n' "$ns" "$child_name" "$actual"
done

printf 'Processed %d HCP resources. Check Ready conditions and ARM provisioning before removing old served versions.\n' "${#rows[@]}"
