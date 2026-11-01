"""Conan 2 deployer for the resolved runtime, build and test dependency graph.

Invoked by conan install --deployer, not as an independent CLI. Writes
application-sbom.cdx.json beneath output_folder, with CI project/revision metadata.
Undeclared vendored or system libraries remain outside this graph.
"""
import json
import os
from pathlib import Path

from conan.tools.sbom import cyclonedx_1_6


def deploy(graph, output_folder, **kwargs):
    """Write CycloneDX 1.6 for graph.root.conanfile, including build/test packages."""
    data = cyclonedx_1_6(graph.root.conanfile, add_build=True, add_tests=True)
    if isinstance(data, str):
        data = json.loads(data)
    component = data.setdefault("metadata", {}).setdefault("component", {})
    component.update(type="application", name=os.environ.get("CI_PROJECT_PATH_SLUG", "application"),
                     version=os.environ.get("CI_COMMIT_SHA", "0.0.0"))
    data.setdefault("components", [])
    destination = Path(output_folder) / "application-sbom.cdx.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
