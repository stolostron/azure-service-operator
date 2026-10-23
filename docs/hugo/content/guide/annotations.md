---
title: Annotations and Labels used by the operator
linktitle: Annotations and Labels
weight: 1 # This is the default weight if you just want to be ordered alphabetically
---

# Annotations

## Annotations written by the user

Note that unless otherwise specified, allowed values are _case sensitive_ and should be provided in lower case.

### `serviceoperator.azure.com/reconcile-policy`

Specifies the reconcile policy to use. Allowed values are:

- `manage`: The operator performs all actions as normal. This is the default if no annotation is specified.
- `skip`: All modification actions on the backing Azure resource are skipped. GETs are still issued to ensure that the resource
exists. If the resource doesn't exist, the `Ready` condition will show a `Warning` state with the details of the missing resource
until the resource is created. If the resource is deleted in Kubernetes, it is _not_ deleted in Azure. In REST API terminology, 
PUT and DELETE are skipped while GET is allowed.
- `detach-on-delete`: Modifications are pushed to the backing Azure resource, but if the resource is deleted in Kubernetes, 
it is _not_ deleted in Azure. In REST API terminology, PUT and GET are allowed while DELETE is skipped.
- `observe-delete`: The operator reads the Azure resource and refreshes status, and deletes it from Azure when the
  Kubernetes resource is deleted. It never creates or updates the Azure resource. In REST API terminology, GET and
  DELETE are allowed while PUT is skipped. A `Ready` condition under this policy confirms the Azure resource can be
  observed; it does not mean spec changes were applied.
    
Unknown values default to `manage`.

### `serviceoperator.azure.com/legacy-swift-placeholder`

Set this to `"true"` on a legacy ARO HCP SWIFT cluster when its `vnetIntegrationSubnetReference` is a placeholder
used only to satisfy the Kubernetes schema. The operator requires `serviceoperator.azure.com/reconcile-policy: observe-delete`
on such an object. This prevents the placeholder from being sent in an ARM PUT. The annotation does not create a
VNet or subnet and does not make the cluster eligible for updates.

### `serviceoperator.azure.com/credential-from`

Instructs the operator to read the credential for the resource from the specified secret. 
This credential supersedes any global or namespace scoped credentials the operator has configured

Allow values are:
- The name of any secret in the same namespace as the resource. Secrets from other namespaces cannot be referenced.

See [authentication]( {{< relref "authentication#credential-scope" >}} ) for more details.

## Annotations written by the operator

These annotations are written by the operator for its own internal use. Their existence and usage may change in the future.
We recommend users avoid depending upon these annotations:

1. `serviceoperator.azure.com/resource-id`: The ARM resource ID.
2. `serviceoperator.azure.com/poller-resume-token`: JSON encoded token for polling long running operation.
3. `serviceoperator.azure.com/poller-resume-id`: ID describing the poller to use.

# Labels

## Labels written by the operator

### `serviceoperator.azure.com/owner-name`

This label contains the name of the resource that owns this resource.
It is written on every resource reconciled by ASO that has an owner. Resources without owners, such as `ResourceGroup`,
do not have this label. The owning resource is guaranteed to be in the same namespace as the resource with this
label.

{{% alert title="Warning" color="warning" %}}
If the owner name is longer than 63 characters it will be truncated to 63 characters.
{{% /alert %}}

### `serviceoperator.azure.com/owner-group-kind`

This label contains the group-kind of the resource that owns this resource.
It is written on every resource reconciled by ASO that has an owner. Resources without owners, such as `ResourceGroup`,
do not have this label.

{{% alert title="Warning" color="warning" %}}
If the owning group-kind is longer than 63 characters it will be truncated to 63 characters.
{{% /alert %}}

### `serviceoperator.azure.com/owner-uid`

This label contains the UID of the resource that owns this resource.
It is written on every resource reconciled by ASO that has an owner. Resources without owners, such as `ResourceGroup`,
do not have this label.

### `serviceoperator.azure.com/last-reconciled-version`

This label contains the version of ASO that last reconciled this resource.
