// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
package storage

import (
	"testing"

	. "github.com/onsi/gomega"

	storage "github.com/Azure/azure-service-operator/v2/api/redhatopenshift/v1api20251223preview/storage"
	"github.com/Azure/azure-service-operator/v2/pkg/genruntime"
)

func TestKmsEncryptionProfile_AssignPropertiesFrom_MovesVaultNameToActiveKey(t *testing.T) {
	// Hub → spoke: VaultName at KmsEncryptionProfile level should move to ActiveKey.VaultName
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"
	keyName := "my-key"

	hub := &storage.KmsEncryptionProfile{
		VaultName: &vaultName,
		ActiveKey: &storage.KmsKey{
			Name: &keyName,
		},
	}

	spoke := &KmsEncryptionProfile{
		ActiveKey: &KmsKey{
			Name: &keyName,
		},
	}

	err := spoke.AssignPropertiesFrom(hub)
	g.Expect(err).To(Succeed())
	g.Expect(spoke.ActiveKey).NotTo(BeNil())
	g.Expect(spoke.ActiveKey.VaultName).NotTo(BeNil())
	g.Expect(*spoke.ActiveKey.VaultName).To(Equal("my-vault"))

	// VaultName should NOT remain in PropertyBag
	if spoke.PropertyBag != nil {
		bag := genruntime.NewPropertyBag(spoke.PropertyBag)
		g.Expect(bag.Contains("VaultName")).To(BeFalse())
	}
}

func TestKmsEncryptionProfile_AssignPropertiesFrom_NilActiveKey_DropsVaultName(t *testing.T) {
	// Hub → spoke: when ActiveKey is nil, VaultName cannot be placed and is dropped
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"

	hub := &storage.KmsEncryptionProfile{
		VaultName: &vaultName,
		ActiveKey: nil,
	}

	spoke := &KmsEncryptionProfile{
		ActiveKey: nil,
	}

	err := spoke.AssignPropertiesFrom(hub)
	g.Expect(err).To(Succeed())
	g.Expect(spoke.ActiveKey).To(BeNil())
}

func TestKmsEncryptionProfile_AssignPropertiesTo_MovesVaultNameToProfileLevel(t *testing.T) {
	// Spoke → hub: ActiveKey.VaultName should move to KmsEncryptionProfile.VaultName
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"
	keyName := "my-key"

	spoke := &KmsEncryptionProfile{
		ActiveKey: &KmsKey{
			Name:      &keyName,
			VaultName: &vaultName,
		},
	}

	hub := &storage.KmsEncryptionProfile{
		ActiveKey: &storage.KmsKey{
			Name: &keyName,
			// Generated KmsKey conversion would put VaultName in PropertyBag here
			PropertyBag: genruntime.PropertyBag{
				"VaultName": `"my-vault"`,
			},
		},
	}

	err := spoke.AssignPropertiesTo(hub)
	g.Expect(err).To(Succeed())
	g.Expect(hub.VaultName).NotTo(BeNil())
	g.Expect(*hub.VaultName).To(Equal("my-vault"))

	// VaultName should be removed from hub's ActiveKey PropertyBag
	if hub.ActiveKey != nil && hub.ActiveKey.PropertyBag != nil {
		bag := genruntime.NewPropertyBag(hub.ActiveKey.PropertyBag)
		g.Expect(bag.Contains("VaultName")).To(BeFalse())
	}
}

func TestKmsEncryptionProfile_RoundTrip_PreservesVaultName(t *testing.T) {
	// Hub → spoke → hub should preserve VaultName
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"
	keyName := "my-key"
	keyVersion := "v1"

	originalHub := &storage.KmsEncryptionProfile{
		VaultName: &vaultName,
		ActiveKey: &storage.KmsKey{
			Name:    &keyName,
			Version: &keyVersion,
		},
	}

	// Hub → spoke
	spoke := &KmsEncryptionProfile{
		ActiveKey: &KmsKey{
			Name:    &keyName,
			Version: &keyVersion,
		},
	}
	err := spoke.AssignPropertiesFrom(originalHub)
	g.Expect(err).To(Succeed())
	g.Expect(spoke.ActiveKey.VaultName).NotTo(BeNil())
	g.Expect(*spoke.ActiveKey.VaultName).To(Equal("my-vault"))

	// Spoke → hub
	roundTrippedHub := &storage.KmsEncryptionProfile{
		ActiveKey: &storage.KmsKey{
			Name:    &keyName,
			Version: &keyVersion,
		},
	}
	err = spoke.AssignPropertiesTo(roundTrippedHub)
	g.Expect(err).To(Succeed())
	g.Expect(roundTrippedHub.VaultName).NotTo(BeNil())
	g.Expect(*roundTrippedHub.VaultName).To(Equal("my-vault"))
}

func TestKmsEncryptionProfile_STATUS_AssignPropertiesFrom_MovesVaultNameToActiveKey(t *testing.T) {
	// Hub → spoke STATUS: VaultName should move to ActiveKey.VaultName
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"
	keyName := "my-key"

	hub := &storage.KmsEncryptionProfile_STATUS{
		VaultName: &vaultName,
		ActiveKey: &storage.KmsKey_STATUS{
			Name: &keyName,
		},
	}

	spoke := &KmsEncryptionProfile_STATUS{
		ActiveKey: &KmsKey_STATUS{
			Name: &keyName,
		},
	}

	err := spoke.AssignPropertiesFrom(hub)
	g.Expect(err).To(Succeed())
	g.Expect(spoke.ActiveKey).NotTo(BeNil())
	g.Expect(spoke.ActiveKey.VaultName).NotTo(BeNil())
	g.Expect(*spoke.ActiveKey.VaultName).To(Equal("my-vault"))
}

func TestKmsEncryptionProfile_STATUS_AssignPropertiesTo_MovesVaultNameToProfileLevel(t *testing.T) {
	// Spoke → hub STATUS: ActiveKey.VaultName should move to KmsEncryptionProfile.VaultName
	t.Parallel()
	g := NewGomegaWithT(t)

	vaultName := "my-vault"
	keyName := "my-key"

	spoke := &KmsEncryptionProfile_STATUS{
		ActiveKey: &KmsKey_STATUS{
			Name:      &keyName,
			VaultName: &vaultName,
		},
	}

	hub := &storage.KmsEncryptionProfile_STATUS{
		ActiveKey: &storage.KmsKey_STATUS{
			Name: &keyName,
			PropertyBag: genruntime.PropertyBag{
				"VaultName": `"my-vault"`,
			},
		},
	}

	err := spoke.AssignPropertiesTo(hub)
	g.Expect(err).To(Succeed())
	g.Expect(hub.VaultName).NotTo(BeNil())
	g.Expect(*hub.VaultName).To(Equal("my-vault"))

	// VaultName should be removed from hub's ActiveKey PropertyBag
	if hub.ActiveKey != nil && hub.ActiveKey.PropertyBag != nil {
		bag := genruntime.NewPropertyBag(hub.ActiveKey.PropertyBag)
		g.Expect(bag.Contains("VaultName")).To(BeFalse())
	}
}
