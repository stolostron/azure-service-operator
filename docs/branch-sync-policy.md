# Branch synchronization & immutability policy

This document is the **source of truth** for how branches in
`stolostron/azure-service-operator` are sourced, synchronized, and protected.
There is no team wiki, so the branch-to-source mapping lives here in the repo.

Tracking: [ARO-29174](https://redhat.atlassian.net/browse/ARO-29174) (follows the
branch reorganization in ARO-27857).

## Branch-to-source mapping

| Branch | Source / basis | Sync mechanism | Immutability |
|---|---|---|---|
| `main` | upstream `Azure/main` + ARO-HCP (2026-06-30-preview) customizations | Periodic **merge** from `Azure/main` via [`sync-upstream-main.yaml`](../.github/workflows/sync-upstream-main.yaml) (opens a PR — not a fast-forward, because `main` carries ARO-HCP customizations) | Open for PRs (default branch) |
| `backplane-5.1` | `stolostron/main` | **FFWD only** from `main` via [`ffwd-branch.yaml`](../.github/workflows/ffwd-branch.yaml) | No direct PRs (blocked by [`protect-backplane-branches.yaml`](../.github/workflows/protect-backplane-branches.yaml) + ruleset) |
| `backplane-5.2` | `stolostron/main` | **FFWD only** from `main` via [`ffwd-branch.yaml`](../.github/workflows/ffwd-branch.yaml) (the same workflow fast-forwards `main` into both `backplane-5.1` and `backplane-5.2`) | No direct PRs (blocked by [`protect-backplane-branches.yaml`](../.github/workflows/protect-backplane-branches.yaml) + ruleset) |
| `backplane-5.0` | `stolostron/release-2.18` | **FFWD only, one-directional** from `release-2.18` via [`ffwd-branch.yaml` (on `release-2.18`)](https://github.com/stolostron/azure-service-operator/blob/release-2.18/.github/workflows/ffwd-branch.yaml) | No direct PRs (blocked by `protect-backplane-branches.yaml` + ruleset) |
| `release-2.19` | upstream v2.19 + ARO-HCP | Manual, security updates only | Immutable except security updates |
| `release-2.18` | upstream v2.18 + ARO-HCP | Manual, security updates only (also feeds `backplane-5.0`) | Immutable except security updates |
| `release-2.13` | upstream v2.13 + ARO-HCP (**former `main`**) | Manual, security updates only | Immutable except security findings |
| `backplane-2.17` | — | Manual, security findings only | Immutable except security findings |
| `backplane-2.11` | — | Manual, security findings only | Immutable except security findings |

## Synchronization workflows

- **`main` ← `Azure/main`** — [`sync-upstream-main.yaml`](../.github/workflows/sync-upstream-main.yaml)
  runs weekly (and on demand). Because `main` carries ARO-HCP customizations, it
  performs a **merge** on a `sync/upstream-main` branch and opens a PR for review.
  Conflicts fail the job so they are resolved manually. Nothing is force-pushed to `main`.
- **`main` → `backplane-5.1`, `backplane-5.2`** — [`ffwd-branch.yaml`](../.github/workflows/ffwd-branch.yaml)
  fast-forwards every push to `main` into both `backplane-5.1` and `backplane-5.2`. One-directional.
- **`release-2.18` → `backplane-5.0`** — [`ffwd-branch.yaml` (on the `release-2.18` branch)](https://github.com/stolostron/azure-service-operator/blob/release-2.18/.github/workflows/ffwd-branch.yaml)
  fast-forwards every push to `release-2.18` into `backplane-5.0`. One-directional.

Fast-forward is deliberate: the `backplane-*` targets must never diverge from
their source. Direct PRs to `backplane-5*` are rejected by
`protect-backplane-branches.yaml`; changes flow only through the source branch.

## Immutability / branch protection (rulesets)

Enforced via GitHub repository **rulesets** (applied through the admin API). The
required posture:

| Branch(es) | Ruleset enforcement |
|---|---|
| `backplane-5.0`, `backplane-5.1`, `backplane-5.2` | Non-fast-forward blocked, deletion blocked; updates only via the FFWD bots. Direct PRs rejected by `protect-backplane-branches.yaml`. |
| `release-2.13`, `backplane-2.17`, `backplane-2.11` | Immutable: no direct pushes, no deletion, no force-push. Changes only for security findings, via reviewed PR. |
| `release-2.18`, `release-2.19` | Protected: no force-push, no deletion. Security updates only, via reviewed PR. |
| `main` | Default protections (PR review + status checks); receives upstream via the sync PR. |

> The mapping table above is authoritative. If a ruleset and this table ever
> disagree, update whichever is wrong so they match.

> **Note.** The `backplane-branches-lockdown` ruleset targets `backplane-5.0`,
> `backplane-5.1`, and `backplane-5.2`. `backplane-5.2` was added after the initial
> ARO-29174 rollout so the ruleset enforcement matches this table.

> **Bot bypass required.** The FFWD and sync workflows push with the Actions
> `GITHUB_TOKEN`. For those pushes to succeed against the protected
> `backplane-5.*` branches, the GitHub Actions bot must be on each ruleset's
> **bypass list**. If it is not, the FFWD jobs fail at the push step even
> though the workflow logic is correct.

> **Manual-dispatch hardening (required).** The FFWD/sync workflows expose
> `workflow_dispatch`. A dispatched run executes the workflow file *as it exists
> on the selected ref*, so an **in-file guard cannot constrain it** — a
> write-access actor could dispatch an altered copy from another ref and, because
> the Actions bot is a ruleset **bypass** principal, have it push arbitrary
> content to a protected `backplane-5.*` branch. This is a settings-level
> control, not a code one: restrict who may run these workflows via GitHub
> **workflow execution protections** (actor rules limiting `workflow_dispatch` to
> maintainers), the same way the ruleset/bypass posture above is enforced through
> settings rather than files. The `push`-triggered path is unaffected because it
> only fires on the trusted source branch (`main` / `release-2.18`).

## Audit — customizations after `main` → `release-2.13`

The previous `main` (now `release-2.13`) accumulated repo/branch-level
configuration. When `main` was re-seeded from `Azure/main`, some stolostron
customizations were silently reverted to their upstream form. This audit compares
**file content** (not just presence) between `release-2.13` and the new `main`.

### Preserved (content identical) ✅

- **GitHub Actions workflows** — full `.github/workflows/` set; no workflow dropped.
- **CodeRabbit** — `.coderabbit.yaml`.
- **PR template / stale bot** — `.github/pull_request_template.md`, `.github/stale.yml`.
- **stolostron downstream carry** — `stolostron/` and `v2/stolostron/` trees
  (CRDs bundle, Dockerfiles, governance, samples): no file dropped.

### Intentional / policy-aligned changes ✅

- **Renovate** — `renovate.json` now targets `main`, `release-*`,
  `backplane-2.11`, `backplane-2.17`; the old `backplane-[0-9]+\.[0-9]+` regex was
  dropped on purpose because `backplane-5.0`/`backplane-5.1` are FFWD-only and must
  not receive independent Renovate PRs.

### Regressions found and fixed in this change ⚠️→✅

- **CODEOWNERS** (`.github/CODEOWNERS`) — the re-seed reverted this to the upstream
  owners (`@theunrepentantgeek @matthchr @tallaxes`), dropping the stolostron
  reviewers. Restored to `@RadekCap @marek-veber @mzazrivec`.
- **Dependabot** (`.github/dependabot.yml`) — old `main` deliberately set
  `updates: []` (Dependabot disabled; Renovate is the dependency tool). The re-seed
  re-enabled the full upstream Dependabot config, which would double up with
  Renovate. Restored to `updates: []`.
- **Konflux / Tekton** — old `main` carried `.tekton` pipelines for `mce-217`,
  `mce-50`, and `mce-51`. Pipelines-as-Code resolves `.tekton` files by cel
  expression, so a pipeline only needs to live on the branches its expression
  matches. The pull-request pipelines whose expression includes
  `target_branch == "main"` live on `main`: `mce-51-pull-request` and
  `mce-52-pull-request` (both present ✅). `mce-50` maps to `backplane-5.0`, which
  is fed from `release-2.18`, so its pull-request pipeline correctly lives on
  `release-2.18` (cel: `target_branch == "backplane-5.0" || target_branch ==
  "release-2.18"`) rather than on `main`; PR #472 updated that pipeline's cel
  expression to trigger on `release-2.18` pull requests (PR #471, which had
  targeted `main`, was closed unmerged and superseded). `mce-217`
  likewise lives on `release-2.18`, and all `-push` pipelines target their own
  branches; none of these need to live on `main`.

Branch rulesets and protection are repository-level settings (not files), so they
are reapplied via the admin API per the table above rather than carried by the
branch move.
