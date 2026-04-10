# Security Scanning — stolostron Fork

This document describes the security scanning posture for the
[stolostron/azure-service-operator](https://github.com/stolostron/azure-service-operator) fork
and records deliberate decisions about which tools are — and are not — enabled.

## Active scanning on this fork

| Tool | Workflow | Trigger | Notes |
|------|----------|---------|-------|
| **CodeQL** | `codeql.yml` | Push/PR to `main`, weekly schedule | Go SAST analysis via GitHub |
| **OpenSSF Scorecard** | `scorecards.yml` | Push to `main`, weekly schedule | Supply-chain security assessment |
| **Gosec** (via golangci-lint) | Part of `controller:lint` task | PR CI | Upstream config — runs as one of many linters in `.golangci.yml` |
| **Trivy** (container image) | `scan-controller-image.yaml` | Weekly schedule, `go.mod` changes | **Only runs on upstream** (`Azure/azure-service-operator`) due to repo guard condition |

## Tools deliberately NOT added

### Nancy (Sonatype OSS Index)

**Decision: Do not add.**

`nancy` is a dependency vulnerability scanner that checks Go modules against the
Sonatype OSS Index. While it is deployed in
[stolostron/capi-tests](https://github.com/stolostron/capi-tests) (our own code),
it is not added to this fork because:

- `govulncheck` already covers the same ground with a more authoritative
  vulnerability database (Go advisory database).
- Nancy's Sonatype OSS Index API has reliability issues that cause spurious CI
  failures.
- This is an upstream fork — dependency changes originate upstream, not here.

### Gosec (standalone workflow)

**Decision: Do not add as a separate CI workflow.**

Gosec is already enabled as a linter within golangci-lint (upstream configuration
in `.golangci.yml`). Adding a standalone gosec workflow would be redundant and
counterproductive because:

- This is an upstream fork where we do not control the source code.
- Gosec findings in upstream code would create noise we cannot fix without
  diverging from upstream.
- The golangci-lint integration already runs gosec checks during CI.

### Additional Trivy scanning on this fork

**Decision: Do not add.**

The upstream `scan-controller-image.yaml` workflow contains a repo guard
(`github.repository == 'Azure/azure-service-operator'`) that disables it on
forks by design. We do not override this because:

- Fighting upstream's workflow structure creates maintenance burden on every
  rebase.
- Container image scanning is handled upstream where the images are built and
  published.

## Rationale

This fork (stolostron) carries minimal divergence from upstream
[Azure/azure-service-operator](https://github.com/Azure/azure-service-operator).
Security scanning tools that analyze source code or dependencies are most
effective on repositories where we control the code. For upstream forks, the
value of adding fork-specific scanners is low relative to the maintenance cost
and CI noise they produce.

Tools that provide value without creating fork-specific noise (CodeQL, Scorecard)
are enabled. Tools that would flag issues in code we don't own (standalone gosec,
nancy) are intentionally excluded.

## References

- JIRA: [ARO-25507](https://redhat.atlassian.net/browse/ARO-25507) — Tier 4: Do not add Nancy or Gosec to CAPZ/ASO forks
- Parent: [ARO-25503](https://redhat.atlassian.net/browse/ARO-25503) — Supply chain vulnerability assessment
