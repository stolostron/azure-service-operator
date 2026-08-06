// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

package storage_test

import (
	"testing"

	. "github.com/onsi/gomega"

	v20251223s "github.com/Azure/azure-service-operator/v2/api/redhatopenshift/v1api20251223preview/storage"
	v20260630s "github.com/Azure/azure-service-operator/v2/api/redhatopenshift/v1api20260630preview/storage"
	"github.com/Azure/azure-service-operator/v2/internal/util/to"
	"github.com/Azure/azure-service-operator/v2/pkg/genruntime"
)

func Test_HcpOpenShiftCluster_v20251223_To_v20260630_RoundTrips(t *testing.T) {
	t.Parallel()
	g := NewGomegaWithT(t)

	src := v20251223s.HcpOpenShiftCluster{}
	src.Spec = v20251223s.HcpOpenShiftCluster_Spec{
		AzureName: "test-cluster",
		Location:  to.Ptr("uksouth"),
		Owner: &genruntime.KnownResourceReference{
			Name: "test-rg",
		},
		Properties: &v20251223s.HcpOpenShiftClusterProperties{
			Api: &v20251223s.ApiProfile{
				Visibility: to.Ptr("Public"),
			},
			Network: &v20251223s.NetworkProfile{
				HostPrefix:  to.Ptr(23),
				NetworkType: to.Ptr("OVNKubernetes"),
				MachineCidr: to.Ptr("10.0.0.0/16"),
				PodCidr:     to.Ptr("10.128.0.0/14"),
				ServiceCidr: to.Ptr("172.30.0.0/16"),
			},
			ClusterImageRegistry: &v20251223s.ClusterImageRegistryProfile{
				State: to.Ptr("Enabled"),
			},
			Etcd: &v20251223s.EtcdProfile{
				DataEncryption: &v20251223s.EtcdDataEncryptionProfile{
					KeyManagementMode: to.Ptr("CustomerManaged"),
					CustomerManaged: &v20251223s.CustomerManagedEncryptionProfile{
						EncryptionType: to.Ptr("KMS"),
						Kms: &v20251223s.KmsEncryptionProfile{
							VaultName: to.Ptr("test-kv"),
							ActiveKey: &v20251223s.KmsKey{
								Name:    to.Ptr("etcd-key"),
								Version: to.Ptr("abc123"),
							},
						},
					},
				},
			},
			Platform: &v20251223s.PlatformProfile{
				ManagedResourceGroup: to.Ptr("managed-rg"),
				OutboundType:         to.Ptr("LoadBalancer"),
			},
			Version: &v20251223s.VersionProfile{
				ChannelGroup: to.Ptr("stable"),
				Id:           to.Ptr("4.19"),
			},
		},
		Tags: map[string]string{"env": "test"},
	}

	// Convert v20251223preview -> v20260630preview (hub)
	hub := v20260630s.HcpOpenShiftCluster{}
	g.Expect(src.AssignProperties_To_HcpOpenShiftCluster(&hub)).To(Succeed())

	// Verify fields arrived at the hub
	g.Expect(hub.Spec.AzureName).To(Equal("test-cluster"))
	g.Expect(*hub.Spec.Location).To(Equal("uksouth"))
	g.Expect(hub.Spec.Properties).ToNot(BeNil())
	g.Expect(*hub.Spec.Properties.Api.Visibility).To(Equal("Public"))
	g.Expect(*hub.Spec.Properties.Network.HostPrefix).To(Equal(23))
	g.Expect(*hub.Spec.Properties.Etcd.DataEncryption.CustomerManaged.Kms.VaultName).To(Equal("test-kv"))
	g.Expect(*hub.Spec.Properties.Etcd.DataEncryption.CustomerManaged.Kms.ActiveKey.Name).To(Equal("etcd-key"))
	g.Expect(*hub.Spec.Properties.Version.Id).To(Equal("4.19"))

	// Convert back v20260630preview (hub) -> v20251223preview
	roundTripped := v20251223s.HcpOpenShiftCluster{}
	g.Expect(roundTripped.AssignProperties_From_HcpOpenShiftCluster(&hub)).To(Succeed())

	// Verify round-trip preserves data
	g.Expect(roundTripped.Spec.AzureName).To(Equal("test-cluster"))
	g.Expect(*roundTripped.Spec.Location).To(Equal("uksouth"))
	g.Expect(*roundTripped.Spec.Properties.Api.Visibility).To(Equal("Public"))
	g.Expect(*roundTripped.Spec.Properties.Network.HostPrefix).To(Equal(23))
	g.Expect(*roundTripped.Spec.Properties.Network.NetworkType).To(Equal("OVNKubernetes"))
	g.Expect(*roundTripped.Spec.Properties.Etcd.DataEncryption.CustomerManaged.Kms.VaultName).To(Equal("test-kv"))
	g.Expect(*roundTripped.Spec.Properties.Etcd.DataEncryption.CustomerManaged.Kms.ActiveKey.Name).To(Equal("etcd-key"))
	g.Expect(*roundTripped.Spec.Properties.Version.Id).To(Equal("4.19"))
	g.Expect(roundTripped.Spec.Tags).To(HaveKeyWithValue("env", "test"))
}

func Test_HcpOpenShiftCluster_v20260630_NewFields_SurviveRoundTrip(t *testing.T) {
	t.Parallel()
	g := NewGomegaWithT(t)

	// Start with a hub resource that has new v20260630preview-only fields
	hub := v20260630s.HcpOpenShiftCluster{}
	hub.Spec = v20260630s.HcpOpenShiftCluster_Spec{
		AzureName: "test-cluster-new",
		Location:  to.Ptr("uksouth"),
		Owner: &genruntime.KnownResourceReference{
			Name: "test-rg",
		},
		Properties: &v20260630s.HcpOpenShiftClusterProperties{
			CryptoRestrictions: to.Ptr("FIPS"),
			Ingress: &v20260630s.IngressProfile{
				Type: to.Ptr("Public"),
			},
			Api: &v20260630s.ApiProfile{
				Visibility: to.Ptr("Private"),
			},
			Version: &v20260630s.VersionProfile{
				ChannelGroup: to.Ptr("stable"),
				Id:           to.Ptr("4.19"),
			},
		},
	}

	// Convert hub -> v20251223preview spoke
	spoke := v20251223s.HcpOpenShiftCluster{}
	g.Expect(spoke.AssignProperties_From_HcpOpenShiftCluster(&hub)).To(Succeed())

	// v20251223preview doesn't have CryptoRestrictions or Ingress natively,
	// they should be stored in PropertyBag
	g.Expect(spoke.Spec.Properties).ToNot(BeNil())
	g.Expect(*spoke.Spec.Properties.Api.Visibility).To(Equal("Private"))
	g.Expect(spoke.Spec.Properties.PropertyBag).ToNot(BeNil())

	// Convert spoke back -> hub
	hubRoundTripped := v20260630s.HcpOpenShiftCluster{}
	g.Expect(spoke.AssignProperties_To_HcpOpenShiftCluster(&hubRoundTripped)).To(Succeed())

	// Verify new fields survived the round-trip through PropertyBag
	g.Expect(hubRoundTripped.Spec.Properties).ToNot(BeNil())
	g.Expect(hubRoundTripped.Spec.Properties.CryptoRestrictions).ToNot(BeNil())
	g.Expect(*hubRoundTripped.Spec.Properties.CryptoRestrictions).To(Equal("FIPS"))
	g.Expect(hubRoundTripped.Spec.Properties.Ingress).ToNot(BeNil())
	g.Expect(*hubRoundTripped.Spec.Properties.Ingress.Type).To(Equal("Public"))
	g.Expect(*hubRoundTripped.Spec.Properties.Api.Visibility).To(Equal("Private"))
	g.Expect(*hubRoundTripped.Spec.Properties.Version.Id).To(Equal("4.19"))
}

func Test_HcpOpenShiftCluster_v20260630_StatusFields_SurviveRoundTrip(t *testing.T) {
	t.Parallel()
	g := NewGomegaWithT(t)

	hub := v20260630s.HcpOpenShiftCluster{}
	hub.Status = v20260630s.HcpOpenShiftCluster_STATUS{
		Location: to.Ptr("uksouth"),
		Properties: &v20260630s.HcpOpenShiftClusterProperties_STATUS{
			CryptoRestrictions: to.Ptr("None"),
			Ingress: &v20260630s.IngressProfile_STATUS{
				Type: to.Ptr("Private"),
			},
			ProvisioningState: to.Ptr("Succeeded"),
			Status: &v20260630s.ResourceStatus_STATUS{
				Conditions: []v20260630s.Condition_STATUS{
					{
						Type:   to.Ptr("Available"),
						Status: to.Ptr("True"),
						Reason: to.Ptr("Ready"),
					},
				},
			},
		},
	}

	// Convert hub status -> v20251223preview spoke
	spoke := v20251223s.HcpOpenShiftCluster{}
	g.Expect(spoke.AssignProperties_From_HcpOpenShiftCluster(&hub)).To(Succeed())

	// Convert spoke back -> hub
	hubRoundTripped := v20260630s.HcpOpenShiftCluster{}
	g.Expect(spoke.AssignProperties_To_HcpOpenShiftCluster(&hubRoundTripped)).To(Succeed())

	// Verify status fields survived
	g.Expect(hubRoundTripped.Status.Properties).ToNot(BeNil())
	g.Expect(*hubRoundTripped.Status.Properties.CryptoRestrictions).To(Equal("None"))
	g.Expect(*hubRoundTripped.Status.Properties.Ingress.Type).To(Equal("Private"))
	g.Expect(*hubRoundTripped.Status.Properties.ProvisioningState).To(Equal("Succeeded"))
	g.Expect(hubRoundTripped.Status.Properties.Status).ToNot(BeNil())
	g.Expect(hubRoundTripped.Status.Properties.Status.Conditions).To(HaveLen(1))
	g.Expect(*hubRoundTripped.Status.Properties.Status.Conditions[0].Type).To(Equal("Available"))
	g.Expect(*hubRoundTripped.Status.Properties.Status.Conditions[0].Status).To(Equal("True"))
}
