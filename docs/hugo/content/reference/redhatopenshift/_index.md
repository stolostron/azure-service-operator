---
title: RedHatOpenShift Supported Resources
linktitle: RedHatOpenShift
no_list: true
---
To install the CRDs for these resources, your ASO configuration must include `redhatopenshift.azure.com/*` as one of the configured CRD patterns. See [CRD Management in ASO](https://azure.github.io/azure-service-operator/guide/crd-management/) for details on doing this for both [Helm](https://azure.github.io/azure-service-operator/guide/crd-management/#helm) and [YAML](https://azure.github.io/azure-service-operator/guide/crd-management/#yaml) based installations.

### Latest Released Versions

These resource(s) are the latest versions available for use in the current release of ASO. Different versions of a given resource reflect different versions of the Azure ARM API.
| Resource                                                                                       | ARM Version        | CRD Version          | Supported From | Sample                                                                                                                                 |
|------------------------------------------------------------------------------------------------|--------------------|----------------------|----------------|----------------------------------------------------------------------------------------------------------------------------------------|
| HcpOpenShiftCluster                                                                            | 2026-09-01-preview | v1api20260901preview | v2.13.0        | -                                                                                                                                      |
| HcpOpenShiftClustersExternalAuth                                                               | 2026-09-01-preview | v1api20260901preview | v2.13.0        | -                                                                                                                                      |
| HcpOpenShiftClustersNodePool                                                                   | 2026-09-01-preview | v1api20260901preview | v2.13.0        | -                                                                                                                                      |
| [OpenShiftCluster]({{< relref "/reference/redhatopenshift/v1api20231122#OpenShiftCluster" >}}) | 2023-11-22         | v1api20231122        | v2.9.0         | [View](https://github.com/Azure/azure-service-operator/tree/main/v2/samples/redhatopenshift/v1api/v1api20231122_openshiftcluster.yaml) |

### Other Supported Versions

These are older versions of resources still available for use in the current release of ASO. Different versions of a given resource reflect different versions of the Azure ARM API.
| Resource                         | ARM Version        | CRD Version          | Supported From | Sample |
|----------------------------------|--------------------|----------------------|----------------|--------|
| HcpOpenShiftCluster              | 2025-12-23-preview | v1api20251223preview | v2.13.0        | -      |
| HcpOpenShiftClustersExternalAuth | 2025-12-23-preview | v1api20251223preview | v2.13.0        | -      |
| HcpOpenShiftClustersNodePool     | 2025-12-23-preview | v1api20251223preview | v2.13.0        | -      |

