"""Expose Drupal PHP extensions to the unmodified GitLab Semgrep analyzer."""
import json
from pathlib import Path
import sys

manifest = Path("reports/sast-aliases.json")
if sys.argv[1] == "prepare":
    aliases = {}
    for source in Path("web/themes/aloha_surf").rglob("*"):
        if source.suffix in (".theme", ".module", ".inc", ".install"):
            alias = Path(str(source) + ".php")
            if alias.exists():
                raise ValueError(f"Refusing to overwrite {alias}")
            alias.write_bytes(source.read_bytes())
            aliases[str(alias)] = str(source)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(aliases, indent=2) + "\n")
    print(f"Prepared {len(aliases)} Drupal PHP aliases for SAST")
elif sys.argv[1] == "normalize":
    aliases = json.loads(manifest.read_text())
    for alias, source in aliases.items():
        if Path(alias).read_bytes() != Path(source).read_bytes():
            raise ValueError("SAST alias differs from its source")
    report = Path("gl-sast-report.json")
    data = json.loads(report.read_text())
    for finding in data["vulnerabilities"]:
        location = finding.get("location", {})
        if location.get("file") in aliases:
            location["file"] = aliases[location["file"]]
    report.write_text(json.dumps(data) + "\n")
    print("Restored original Drupal source paths in the SAST report")
else:
    raise ValueError("Expected prepare or normalize")
