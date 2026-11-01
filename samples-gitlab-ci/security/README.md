# Security pipeline examples

Two profiles share `pipeline.py` and its release policy:

| Profile | Application dependencies | Tests | Artifact |
| --- | --- | --- | --- |
| `django` | pip-audit, OWASP Dependency-Check on resolved wheels | Django tests and coverage | Docker image archive |
| `surfnews` | Composer audit, OWASP Dependency-Check on composer.lock | Actual Aloha Surf hooks, PHP syntax and theme metadata | Drupal/PHP Docker image archive |

Both profiles run the official GitLab Secret Detection, Semgrep SAST and Container
Scanning templates, SonarQube analysis, application and container CycloneDX SBOMs,
DefectDojo imports and a blocking release policy, then upload the approved image,
both SBOMs and approval evidence to a Nexus **raw hosted** repository.

For Drupal, `.theme`, `.module`, `.inc` and `.install` files are exposed to
Semgrep as byte-identical `.php` aliases during its job; the report is mapped back
to the original source paths. The alias manifest is retained as an artifact.
SonarQube explicitly recognizes these Drupal PHP suffixes as well.

These are GitLab **CE** examples. GitLab's native Dependency Scanning requires
Ultimate; pip-audit/Composer audit and Dependency-Check are explicit substitutes,
not GitLab Dependency Scanning. CE stores the scanner JSON as downloadable
artifacts; the Ultimate vulnerability dashboards are not provided by this example.

## Prepare a project

From the OSSF repository, prepare a new directory (the destination must not exist):

```sh
python3 samples-gitlab-ci/security/prepare-example.py surfnews /tmp/surfnews-ci \
  --source /Users/antoine/Documents/Workspace/Surfnews
```

The Surfnews snapshot includes only composer.json, composer.lock and the custom
Aloha Surf theme. Composer reconstructs vendor/core/contributed code. It excludes
the workstation README containing local credentials, settings.php, site files,
database content and local process scripts. The source folder is not modified.
The supplied lock had an outdated content hash: `composer update --lock
--no-install --no-scripts --no-plugins` refreshed the test snapshot without changing
package versions. Commit a consistent lock before running the CI.

For an existing Django application:

```sh
python3 samples-gitlab-ci/security/prepare-example.py django /tmp/django-ci
```

Copy that overlay into the application project. No demo application is included.
Supply manage.py and the application modules; adapt requirements.txt, the Dockerfile
(currently expecting a `surfnews` Django package), sonar-project.properties and
the coverage configuration to the real app. Python 3.14 and Django 6.1 are used
by the sample pins; choose versions supported by your application together.

The copied `ci/pipeline.py` is required. Keep it aligned with the YAML when copying
future revisions; the preparation tool installs it automatically.

## Runner and services

Use a **project runner**, tagged `ossf-security`, locked to this private project,
with untagged jobs disabled and access restricted to protected refs. Configure
the Docker executor, `concurrent = 1`, `privileged = true`, and Docker volumes
`["/certs/client", "/cache"]`. Docker-in-Docker uses TLS on port 2376. Do not mount
the host Docker socket. This privileged runner must only execute trusted code.

Create/register the runner using GitLab's UI authentication token; do not commit
it to the repository. The workflow runs on the **protected default branch** only.
SonarQube Community Build analyzes one branch per project. The Sonar analysis job
uses a resource group and verifies the analysis ID/revision before and after
exporting issues, so overlapping pipelines cannot silently mix results.

GitLab documents AMD64 as the supported architecture for these analyzers. The
ARM64 VMware lab uses Ubuntu `qemu-user-binfmt`; analyzer jobs explicitly request
`linux/amd64`. This emulated setup is a lab adaptation, outside GitLab's supported
runner architecture. Use a native AMD64 runner for a supported deployment. The
lab also sets the protected project variable `QEMU_GUEST_BASE=0x800000000000`:
QEMU otherwise maps Go runtime allocations outside AMD64's canonical user range,
causing `lfstack.push` crashes. This affects only emulated process mappings; it
does not change host ASLR. A real Secret Detection probe passed with this setting.
Set the project's maximum artifact size to 512 MB for the PHP image archive.
The VM must have enough free RAM/disk for GitLab, DefectDojo, a scanner and the build
daemon; one job runs at a time.
The VMware lab runner also sets Docker container `dns = ["1.1.1.1", "8.8.8.8"]`
because Docker-in-Docker failed to resolve Docker Hub through the VMware NAT DNS.
This setting belongs to this runner's config.toml; the VM/system DNS is unchanged.

Create a private SonarQube project, a DefectDojo product and a Nexus raw hosted
repository. Give the Sonar CI user Browse and Execute Analysis only on its
project; give the non-staff/non-superuser Dojo user access only to its product.
Check inherited permissions too: SonarQube's default `sonar-users` group initially
granted global Execute Analysis and Create Projects in this lab. With explicit
user authorization, these two grants were removed from that group, while admin
retained its effective permissions and the CI user retained its project grants.
Future users need explicit project permissions.
Give the Nexus CI user browse/read/add/edit only for its raw repository, with an
immutable (`ALLOW_ONCE`) write policy. No OSSF administrator passwords belong in CI.
Complete Nexus Community Edition's onboarding and explicitly review/accept its
[EULA](https://links.sonatype.com/products/nxrm/ce-eula) as administrator before
publishing: an unaccepted EULA causes HTTP 403 even with correct repository
privileges. No CI job accepts legal terms automatically.

Set these **protected** project variables. Mask the three secrets:

| Variable | Lab value/purpose |
| --- | --- |
| `SONAR_HOST_URL` | `http://172.16.57.143:9000` |
| `SONAR_PROJECT_KEY` | Private project key |
| `SONAR_TOKEN` | Dedicated project user's token; masked |
| `DEFECTDOJO_URL` | `http://172.16.57.142:8088` |
| `DEFECTDOJO_PRODUCT_ID` | Dedicated product ID |
| `DEFECTDOJO_TOKEN` | Non-administrator product user's token; masked |
| `NEXUS_URL` | `http://172.16.57.144:8081` |
| `NEXUS_REPOSITORY` | Raw hosted repository, e.g. `ossf-ci` |
| `NEXUS_USER` | Dedicated publisher |
| `NEXUS_PASSWORD` | Dedicated publisher password; masked |
| `DD_MIN_SEVERITY` | `High` by default; Critical/High/Medium/Low/Info |

The URLs are origins, without paths or trailing API endpoints. Use TLS outside
this local HTTP lab. The optional local `config/ci-surfnews.env` is ignored by Git
and mode 600; it is separate from the administrator installation configuration.

Dependency-Check enables its experimental Python/Composer analyzers. It uses the
project's official NVD data feed and caches its database. OSS Index enrichment is
disabled because it requires separate credentials; NVD/CPE and the package audit
remain enabled. A failed update/scan fails the job; no empty report is substituted.
Dependency-Check is complementary to the ecosystem audit, not a replacement for it.
The job exports JSON, XML and HTML. DefectDojo 3.3.200's Dependency Check parser
accepts XML; the barrier checks the JSON for scan errors and verifies that both
inventories have the same number of dependencies before importing the XML.

## Release policy

All eight reports are mandatory. Scanner errors block the pipeline. Vulnerability
findings are imported with `deduplication_execution_mode=sync` into an engagement
unique to the project/pipeline/job; incomplete imports fail the barrier. Findings
are paginated and evaluated within this engagement, including unverified findings.
Duplicates also count conservatively. Missing reports and unknown severities fail.

Publication requires SonarQube's gate to be `OK`, no open finding at or above
`DD_MIN_SEVERITY`, and no pip-audit/Composer advisory (these reports do not always
have reliable severity). The barrier saves a summary even when refusing release.
Approval is written only on success, binding the commit/pipeline and the SHA-256
of the built Docker archive and both SBOMs. Nexus verifies those hashes again
before upload and checks the stored bytes afterwards. The same built image is
scanned and published; it is never rebuilt after approval.

Container Scanning accepts the `docker save` archive directly (`archive://`);
there is no intermediate registry or insecure registry configuration. Nexus
receives `image.tar`, the application/container SBOMs and approval.json under
`<project-id>/<commit>/<pipeline-id>/`. This is an image archive repository, not
a Docker registry endpoint. The approval file is uploaded last; consumers must
require it so a partial upload is not treated as a complete release. Rerun a
pipeline to obtain a new immutable path after a partial publication failure.
Use `docker load` to consume the approved image.
The outer tar is not gzipped: GCS 8.7.1 reads the archive manifest for each
vulnerability, making repeated gzip decompression prohibitively slow under QEMU.
Docker's layers are already compressed; the measured Surfnews tar was about
280 MiB, compared with 278 MiB with an additional gzip wrapper.

The Surfnews image contains code/dependencies, not the live site's data. At
deployment supply PostgreSQL DATABASE_URL, DRUPAL_HASH_SALT and trusted host
patterns; install/import the site's database separately. The CI theme tests do
not claim to exercise the entire live site or its existing content.

## Validation

```sh
python3 -m venv /tmp/ossf-ci-tests
/tmp/ossf-ci-tests/bin/pip install requests==2.34.2
/tmp/ossf-ci-tests/bin/python -m unittest discover \
  -s samples-gitlab-ci/security -p 'test_*.py'
```

Tests cover missing/failed scans, incomplete imports, pagination, unverified High
findings, unknown severity, Sonar refusal, cross-origin credential protection and
artifact tampering. See RESULTS.md for executed live checks and their limits.

References: [GitLab Dependency Scanning](https://docs.gitlab.com/user/application_security/dependency_scanning/),
[GitLab SAST prerequisites](https://docs.gitlab.com/user/application_security/sast/),
[container archive scanning](https://docs.gitlab.com/user/application_security/container_scanning/#scanning-archive-formats),
[Dependency-Check Python support](https://dependency-check.github.io/DependencyCheck/analyzers/python.html),
[official NVD feed](https://github.com/dependency-check/DependencyCheck_Builder/blob/main/Dockerfile),
[CycloneDX Composer](https://github.com/CycloneDX/cyclonedx-php-composer).
