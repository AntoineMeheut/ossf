# CI validation — 2026-11-01

The supplied application was `/Users/antoine/Documents/Workspace/Surfnews`:
Drupal 10.6.0, Composer and the original Aloha Surf theme. Its source folder,
database, site settings and uploaded content were not changed. The isolated
snapshot refreshed only the stale Composer lock content hash; package versions
remained unchanged.

The private [GitLab test project](http://172.16.57.142/root/surfnews-ci-example)
uses a dedicated protected Docker runner on VM 1. SonarQube, DefectDojo and Nexus
use separate CI identities scoped to their project/product/repository. The Nexus
Community Edition EULA was accepted after the user's explicit authorization.
With separate explicit authorization, SonarQube's default `sonar-users` group
lost its global Execute Analysis and Create Projects grants. Admin's effective
rights were preserved, and the CI user's explicit project Browse/Execute Analysis
grants and reporting API access were verified after the change.
The actual SonarQube job was then rerun successfully with the same CI token
and returned quality status `OK` (job 86 in pipeline 7).

## Executed checks

The complete run is [pipeline 7](http://172.16.57.142/root/surfnews-ci-example/-/pipelines/7),
commit `49c6ec748d4abbb0a67b0dd505b8a06c5bf04b01`. All prepare, test, build and
scanner jobs succeeded. The pipeline's final **failed** status is the expected
release-policy refusal, not an interrupted scanner or integration failure.

- Both complete CI profiles passed the installed GitLab 19.4 CI Lint compiler.
- The repository's CI validator now discovers all six examples, including the
  nested hidden `.gitlab-ci.yml` files; Ruby syntax and file discovery passed.
- Seventeen Python policy tests passed, including missing/failed scans,
  inconsistent OWASP inventories, unfinished imports, pagination, unknown and
  unverified severities, dependency advisories, Sonar refusal, artifact tampering,
  upload/readback and credential-safe transport errors.
- The real Surfnews theme hooks, metadata and PHP syntax passed locally and in
  the registered GitLab Runner. No demonstration Django application was used.
- GitLab Secret Detection and Semgrep SAST completed. The SAST alias manifest
  confirms coverage of the original `aloha_surf.theme` file. SonarQube indexed
  this file as PHP and returned quality status `OK`.
- The final Secret Detection report contains no findings. Semgrep reports one
  Medium XML parsing finding in `ci/pipeline.py`; it is retained in the report.
  SonarQube exported 36 issues. A successful scanner job means the scan ran,
  rather than an assertion that its findings are acceptable for release.
- Composer audit reported 59 advisories across 11 packages: 2 Critical, 8 High,
  25 Medium, 8 Low and 16 without a supplied severity.
- OWASP Dependency-Check 13.0.0 analyzed 79 locked dependencies. Its official
  XML output imported synchronously into DefectDojo; JSON/XML inventory counts
  matched. CycloneDX Composer 6.2.0 produced a 1.6 SBOM with 79 components.
- GitLab Container Scanning completed successfully under emulation in about
  13 minutes. Its report contains 4,090 results: 4 Critical, 269 High, 2,354
  Medium, 1,452 Low and 11 Unknown. Its CycloneDX SBOM contains 208 components.
  These are raw scanner results, before DefectDojo deduplication or triage.
- Real Composer, CycloneDX, OWASP XML and SonarQube reports imported with the
  restricted Dojo account. Imports returned `deduplication_complete=true`.
- The restricted Nexus publisher uploaded and read back a clearly labelled
  transport probe with matching bytes. That probe is not a Surfnews release.

## End-to-end policy decision

[Barrier job 84](http://172.16.57.142/root/surfnews-ci-example/-/jobs/84)
successfully imported all eight reports synchronously into
[DefectDojo engagement 2](http://172.16.57.142:8088/engagement/2), tests 6–13.
It then evaluated every page of active findings and refused publication:

| DefectDojo severity | Active results counted by policy |
| --- | ---: |
| Critical | 65 |
| High | 449 |
| Medium | 2,694 |
| Low | 1,479 |
| Info | 17 |

These are scanner/importer results requiring triage, not independently confirmed
vulnerabilities. The conservative counts include unverified and duplicate results.
The barrier also independently counted 59 Composer advisories and 11 container
results with unknown severity. SonarQube's own quality gate was `OK`.

`reports/gate-summary.json` is retained in job 84's artifacts; no `approval.json`
was created. GitLab skipped `publish_nexus` (job 85). A subsequent paginated Nexus
inventory check confirmed only the transport probe exists and no Surfnews release
was published. The real negative policy path and real repository write access
were verified separately; a successful application publication is not claimed.

After the final CI Lint checks, the temporary GitLab root API token was revoked
(HTTP 204); an immediate request using that token returned HTTP 401. The dedicated
runner and scoped operational CI credentials remain configured. Their local copy
is `config/ci-surfnews.env`, ignored by Git and readable only by its owner (0600).

## Scope and environment

The runtime validation targets Surfnews. The Django profile was compiled by
GitLab and shares the tested policy code; it was not executed against a Django
application. PHP tests exercise the original theme hooks and metadata, not the
entire existing site's content or a production database.

The lab runs Ubuntu 26.04 ARM64 with Docker 29.8.1 and Runner 19.4.1. The official
GitLab analyzer images run as AMD64 through QEMU. This is outside GitLab's
supported native AMD64 runner architecture. A protected `QEMU_GUEST_BASE` setting
avoids the observed Go allocation crash; runner-specific container DNS avoids a
VMware NAT DNS failure. The README documents these settings and the archive
permission/format requirements.

Live application publication must remain blocked while the release policy
rejects the findings. Positive publisher behavior is covered by policy tests and
the separate live Nexus transport check; no failing scan is treated as clean.
