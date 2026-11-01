# Shared security CI helpers

The repository provides generic Django and Angular CI overlays. The full setup,
project adaptation, Runner configuration, CI variable reference, release policy
and troubleshooting guide are in the root [README.md](../../README.md#gitlab-ci-examples).

`prepare-example.py` creates an overlay without reading application source.
`pipeline.py` validates reports, exports SonarQube results, enforces the DefectDojo
barrier and publishes approved artifacts to Nexus. Copy it as `ci/pipeline.py`
alongside the selected overlay; the preparation tool does this automatically.
`test_pipeline.py` tests the shared policy without contacting external services.
