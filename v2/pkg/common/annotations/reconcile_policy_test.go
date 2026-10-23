// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

package annotations

import "testing"

func TestObserveDeleteAllowsDeletionWithoutModification(t *testing.T) {
	if ReconcilePolicyObserveDelete.AllowsModify() {
		t.Fatal("observe-delete must not permit ARM PUT")
	}
	if !ReconcilePolicyObserveDelete.AllowsDelete() {
		t.Fatal("observe-delete must permit ARM DELETE")
	}
}
