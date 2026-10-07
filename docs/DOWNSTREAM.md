# Downstream context (stolostron / ARO-HCP)

Entry point for the fork-specific layer of this repository. This file covers
only what is **specific to the stolostron fork** — it does not duplicate
upstream documentation.

> **This is a downstream fork.** The engineering source of truth for ASO
> architecture, controller patterns, CRD generation, and build/test commands
> lives upstream in [`Azure/azure-service-operator`](https://github.com/Azure/azure-service-operator).
> Start with [`v2/README.md`](../v2/README.md) and [`CONTRIBUTING.md`](../CONTRIBUTING.md).
> This page adds only the stolostron/ARO-HCP layer on top.

## What this fork is

`stolostron/azure-service-operator` packages the ASO controller for
**Azure Red Hat OpenShift Hosted Control Planes (ARO-HCP)** and ships it as
part of **multicluster engine (MCE) / backplane** via
[Konflux](https://konflux-ci.dev/) builds.

The Go module path stays `github.com/Azure/azure-service-operator/v2` — this
fork does not rename the module.

## How it differs from upstream

The Go source in `v2/` is kept as close to upstream as possible. The
downstream-only pieces are the ARO-HCP API version pin, the branch model, the
upstream sync workflow, and the Konflux build configuration.

| Concern | Where it lives | Notes |
|---------|----------------|-------|
| Upstream sync | [`.github/workflows/sync-upstream-main.yaml`](../.github/workflows/sync-upstream-main.yaml) | Weekly (Mon 06:00 UTC) + manual dispatch. Merges `upstream/main` into a `sync/upstream-main` branch and opens a regular PR. On any conflict the job fails; resolve the merge manually on `sync/upstream-main` and push to unblock. |
| Branch fast-forward | [`.github/workflows/ffwd-branch.yaml`](../.github/workflows/ffwd-branch.yaml) | Every push to `main` is fast-forwarded into `backplane-5.1`. One-directional — direct PRs to `backplane-5.*` are rejected. |
| Downstream build | [`stolostron/Dockerfile.stolostron`](../stolostron/Dockerfile.stolostron) | Red Hat UBI9-based image for MCE packaging. Built by Konflux. |
| Konflux pipelines | [`.tekton/`](../.tekton) | Tekton `PipelineRun` definitions for MCE releases, split into `-pull-request` and `-push` variants. |
| Branch policy | [`docs/branch-sync-policy.md`](branch-sync-policy.md) | Authoritative branch-to-source mapping and protection rules. |

## Dependency security updates

Renovate is configured in [`renovate.json`](../renovate.json) to open grouped
pull requests only for detected dependency vulnerabilities with an available
fix. Routine version and digest updates are disabled. Keep GitHub's dependency
graph and Dependabot alerts enabled. The Renovate workflow is manually
dispatched, so vulnerability alerts are processed when that workflow runs.

## Branch model

The authoritative source is [`docs/branch-sync-policy.md`](branch-sync-policy.md).
Summary:

| Branch | Source | Sync mechanism |
|--------|--------|----------------|
| `main` | `Azure/main` + ARO-HCP customizations | Weekly merge-based sync via `sync-upstream-main.yaml` (PR-based, not fast-forward) |
| `backplane-5.1` | `main` | FFWD-only via `ffwd-branch.yaml` on every push to `main` |
| `backplane-5.0` | `release-2.18` | Manual (no automated sync) |
| `release-2.18`, `release-2.19` | upstream release branches + ARO-HCP | Manual, security updates only |
| `backplane-2.17`, `backplane-2.11` | — | Manual, security findings only |

## Working with the fork

- **All PRs target `main`.** Changes flow to `backplane-5.1` automatically via
  the fast-forward workflow. Never open a PR directly against a `backplane-*`
  branch — it will be rejected.
- **Keep changes upstream-friendly.** Prefer contributing fixes upstream and
  letting them flow down via the sync. Downstream-only patches make every future
  sync harder to merge.
- **Upstream sync conflicts.** When the sync workflow fails on a conflict, it
  emits an error in the Actions log. Resolve the merge manually on the
  `sync/upstream-main` branch and push to unblock.
- **Do not edit upstream-tracked content to add downstream notes.** Put
  downstream-specific context in this file instead.

## Start here

| Document | What it covers |
|----------|----------------|
| [AGENTS.md](../AGENTS.md) | Repository index for AI agents — all key docs and directories. |
| [v2/README.md](../v2/README.md) | ASO v2 — what it is, installation, supported resources. |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Upstream contribution workflow. |
| [docs/branch-sync-policy.md](branch-sync-policy.md) | Authoritative branch protection and sync rules. |
| [SECURITY.md](../SECURITY.md) | Vulnerability reporting. |
