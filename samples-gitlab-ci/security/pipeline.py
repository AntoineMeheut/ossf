"""CI integrations. Missing reports, incomplete imports and API errors fail closed."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urljoin, urlparse
from xml.etree import ElementTree

import requests


REPORTS = (
    ("gl-secret-detection-report.json", "GitLab Secret Detection Report", "vulnerabilities"),
    ("gl-sast-report.json", "GitLab SAST Report", "vulnerabilities"),
    ("reports/pip-audit.json", "pip-audit Scan", "dependencies"),
    ("reports/dependency-check-report.xml", "Dependency Check Scan", "dependencies"),
    ("gl-container-scanning-report.json", "GitLab Container Scan", "vulnerabilities"),
    ("reports/application-sbom.cdx.json", "CycloneDX Scan", "components"),
    ("gl-sbom-report.cdx.json", "CycloneDX Scan", "components"),
    ("reports/sonarqube.json", "SonarQube Scan", "issues"),
)
SEVERITIES = ("Critical", "High", "Medium", "Low", "Info")


def reports():
    if os.environ.get("OSSF_PROFILE", "django") == "surfnews":
        return tuple(("reports/composer-audit.json", "Composer Audit Scan", "advisories")
                     if item[0] == "reports/pip-audit.json" else item for item in REPORTS)
    return REPORTS


def required(name):
    value = os.environ.get(name, "")
    if not value.strip():
        raise ValueError(f"Required CI variable is missing: {name}")
    return value


def read_json(path):
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream)


def write_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def digest(path):
    checksum = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


class API:
    def __init__(self, base, token=None, auth=None, scheme="Bearer"):
        parsed = urlparse(base)
        if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("API URL must be an HTTP(S) origin without credentials")
        if parsed.path not in ("", "/") or parsed.query or parsed.fragment:
            raise ValueError("API URL must not contain a path, query or fragment")
        self.base = base.rstrip("/") + "/"
        self.session = requests.Session()
        self.session.trust_env = False
        self.session.auth = auth
        if token:
            self.session.headers["Authorization"] = f"{scheme} {token}"

    def request(self, method, path, **kwargs):
        url = urljoin(self.base, path)
        if urlparse(url).netloc != urlparse(self.base).netloc or urlparse(url).scheme != urlparse(self.base).scheme:
            raise ValueError("Refusing an API pagination/redirect URL on another origin")
        response = self.session.request(method, url, timeout=(10, 180), allow_redirects=False, **kwargs)
        if not 200 <= response.status_code < 300:
            # Do not echo bodies: authentication errors can include submitted secrets.
            raise RuntimeError(f"API request failed: {method} {urlparse(url).path}: HTTP {response.status_code}")
        return response

    def json(self, method, path, **kwargs):
        return self.request(method, path, **kwargs).json()


def validate_reports():
    for filename, _, key in reports():
        if filename.endswith("dependency-check-report.xml"):
            data = read_json("reports/dependency-check-report.json")
            validate_dependency_check(data)
            root = ElementTree.parse(filename).getroot()
            dependencies = root.find("{*}dependencies")
            if root.tag.split("}")[-1] != "analysis" or dependencies is None or len(dependencies) != len(data["dependencies"]):
                raise ValueError("Dependency-Check XML and JSON inventories do not match")
            continue
        data = read_json(filename)
        expected_type = (dict, list) if key == "advisories" else (list,)
        if not isinstance(data, dict) or not isinstance(data.get(key), expected_type):
            raise ValueError(f"Missing/invalid report payload: {filename} ({key})")
        if key == "vulnerabilities" and data.get("scan", {}).get("status") != "success":
            raise ValueError(f"Scanner did not complete successfully: {filename}")
        if "sbom" in filename and (data.get("bomFormat") != "CycloneDX" or not data[key]):
            raise ValueError(f"Invalid/empty CycloneDX inventory: {filename}")
        if filename.endswith("pip-audit.json"):
            if not data[key] or any(item.get("skip_reason") for item in data[key]):
                raise ValueError("pip-audit skipped a dependency or produced no inventory")
        if filename.endswith("dependency-check-report.json"):
            validate_dependency_check(data)
    return {filename: digest(filename) for filename in [*(item[0] for item in reports()), "reports/dependency-check-report.json"]}


def validate_dependency_check(data):
    if not data.get("dependencies") or data.get("scanInfo", {}).get("analysisExceptions"):
        raise ValueError("Dependency-Check inventory is empty or analysis was incomplete")


def audit():
    result = subprocess.run(
        [".tools/bin/pip-audit", "--path", ".venv/lib/python3.14/site-packages", "--format", "json", "--output", "reports/pip-audit.json"],
        check=False,
    )
    data = read_json("reports/pip-audit.json")
    dependencies = data.get("dependencies", [])
    if not dependencies or any(item.get("skip_reason") for item in dependencies):
        raise ValueError("pip-audit inventory is missing or incomplete")
    findings = sum(len(item.get("vulns", [])) for item in dependencies)
    if result.returncode != 0 and not (result.returncode == 1 and findings > 0):
        raise RuntimeError("pip-audit failed; no valid vulnerability-only exit status")
    print(f"pip-audit completed: {findings} findings; policy is enforced by DefectDojo")


def sonar_export():
    api = API(required("SONAR_HOST_URL"), required("SONAR_TOKEN"))
    task_info = dict(line.split("=", 1) for line in Path("reports/sonar-task.txt").read_text().splitlines() if "=" in line)
    project = required("SONAR_PROJECT_KEY")
    if task_info.get("projectKey") != project:
        raise ValueError("SonarQube task belongs to a different project")
    deadline = time.monotonic() + int(os.environ.get("SONAR_TIMEOUT", "900"))
    while True:
        task = api.json("GET", "/api/ce/task", params={"id": task_info["ceTaskId"]})["task"]
        if task["status"] == "SUCCESS":
            break
        if task["status"] in ("FAILED", "CANCELED") or time.monotonic() >= deadline:
            raise RuntimeError("SonarQube background analysis failed or timed out")
        time.sleep(5)
    quality = api.json("GET", "/api/qualitygates/project_status", params={"analysisId": task["analysisId"]})
    # Community Build has one analysis branch per project. Refuse a report superseded
    # by another analysis instead of mixing snapshots from concurrent pipelines.
    latest = api.json("GET", "/api/project_analyses/search", params={"project": project, "ps": 1})["analyses"][0]
    if latest["key"] != task["analysisId"] or latest.get("revision") != required("CI_COMMIT_SHA"):
        raise ValueError("SonarQube analysis is stale or has a different source revision")
    merged = {"issues": [], "components": [], "paging": {"pageIndex": 1, "pageSize": 500, "total": 0}}
    for endpoint, key in (("issues", "issues"), ("hotspots", "hotspots")):
        items = []
        page = 1
        while True:
            params = {"componentKeys" if key == "issues" else "projectKey": project, "p": page, "ps": 500}
            if key == "issues":
                params["resolved"] = "false"
            response = api.json("GET", f"/api/{endpoint}/search", params=params)
            batch = response[key]
            items.extend(batch)
            merged["components"].extend(response.get("components", []))
            total = response["paging"]["total"]
            if len(items) >= total:
                if len(items) != total:
                    raise ValueError("SonarQube pagination changed during export")
                break
            if not batch or len(items) >= 10000:
                raise ValueError("Incomplete SonarQube export (empty page or API result limit)")
            page += 1
        merged[key] = items
    latest_after = api.json("GET", "/api/project_analyses/search", params={"project": project, "ps": 1})["analyses"][0]
    if latest_after["key"] != task["analysisId"]:
        raise ValueError("SonarQube project changed during export")
    merged["paging"]["total"] = len(merged["issues"])
    write_json("reports/sonarqube.json", merged)
    quality.update({"commit": required("CI_COMMIT_SHA"), "analysis_id": task["analysisId"]})
    write_json("reports/sonar-quality-gate.json", quality)
    print("SonarQube results exported; quality status:", quality["projectStatus"]["status"])


def findings(api, engagement):
    path = f"/api/v2/findings/?test__engagement={engagement}&active=true&limit=100"
    seen = set()
    items = []
    expected = None
    while path:
        if path in seen:
            raise ValueError("DefectDojo pagination loop")
        seen.add(path)
        data = api.json("GET", path)
        expected = data["count"] if expected is None else expected
        if data["count"] != expected:
            raise ValueError("DefectDojo findings changed during evaluation")
        items.extend(data["results"])
        path = data["next"]
    if len(items) != expected or len({item["id"] for item in items}) != len(items):
        raise ValueError("Incomplete or duplicate DefectDojo result pages")
    return items


def gate():
    Path("reports/approval.json").unlink(missing_ok=True)
    report_hashes = validate_reports()
    quality = read_json("reports/sonar-quality-gate.json")
    if quality.get("commit") != required("CI_COMMIT_SHA"):
        raise ValueError("SonarQube report belongs to a different commit")
    threshold = os.environ.get("DD_MIN_SEVERITY", "High")
    if threshold not in SEVERITIES:
        raise ValueError("DD_MIN_SEVERITY must be Critical, High, Medium, Low or Info")
    api = API(required("DEFECTDOJO_URL"), required("DEFECTDOJO_TOKEN"), scheme="Token")
    today = time.strftime("%Y-%m-%d", time.gmtime())
    engagement = api.json("POST", "/api/v2/engagements/", json={
        "name": f"CI {required('CI_PROJECT_ID')}/{required('CI_PIPELINE_ID')}/{required('CI_JOB_ID')}",
        "product": int(required("DEFECTDOJO_PRODUCT_ID")), "target_start": today, "target_end": today,
        "status": "In Progress", "engagement_type": "CI/CD", "deduplication_on_engagement": True,
    })["id"]
    imported = []
    for filename, scan_type, _ in reports():
        with Path(filename).open("rb") as stream:
            result = api.json("POST", "/api/v2/import-scan/", data={
                "engagement": engagement, "scan_type": scan_type, "test_title": filename,
                "active": "true", "verified": "false", "minimum_severity": "Info",
                "close_old_findings": "false", "deduplication_execution_mode": "sync",
                "commit_hash": required("CI_COMMIT_SHA"), "build_id": required("CI_PIPELINE_ID"),
            }, files={"file": (Path(filename).name, stream, "application/xml" if filename.endswith(".xml") else "application/json")})
        if result.get("deduplication_complete") is not True or not result.get("test_id"):
            raise ValueError(f"Import did not complete synchronously: {filename}")
        imported.append(result["test_id"])
    counts = dict.fromkeys(SEVERITIES, 0)
    for item in findings(api, engagement):
        severity = item["severity"]
        if severity not in counts:
            raise ValueError("DefectDojo returned an unknown severity")
        # Unverified and duplicate findings still count: conservative release policy.
        if item["active"] and not item.get("is_mitigated") and not item.get("false_p") and not item.get("out_of_scope"):
            counts[severity] += 1
    blocked = sum(counts[name] for name in SEVERITIES[:SEVERITIES.index(threshold) + 1])
    unknown_severities = sum(
        finding.get("severity") not in SEVERITIES
        for filename, _, key in reports() if key == "vulnerabilities"
        for finding in read_json(filename)[key]
    )
    # pip-audit does not supply CVSS severity for every advisory. Never allow an
    # advisory merely because the importer assigned it a lower/default severity.
    if os.environ.get("OSSF_PROFILE", "django") == "surfnews":
        advisories = read_json("reports/composer-audit.json")["advisories"]
        dependency_findings = sum(len(value) for value in advisories.values()) if isinstance(advisories, dict) else len(advisories)
    else:
        dependency_findings = sum(len(item.get("vulns", [])) for item in read_json("reports/pip-audit.json")["dependencies"])
    summary = {"engagement": engagement, "tests": imported, "counts": counts, "threshold": threshold,
               "sonar_quality_gate": quality["projectStatus"]["status"], "dependency_advisories": dependency_findings,
               "unknown_scanner_severities": unknown_severities, "reports": report_hashes}
    write_json("reports/gate-summary.json", summary)
    print(json.dumps({key: summary[key] for key in ("engagement", "counts", "sonar_quality_gate", "dependency_advisories", "unknown_scanner_severities")}))
    if blocked or dependency_findings or unknown_severities or summary["sonar_quality_gate"] != "OK":
        raise ValueError("Quality barrier refused publication; see reports/gate-summary.json")
    approval = {"commit": required("CI_COMMIT_SHA"), "pipeline": required("CI_PIPELINE_ID"), **summary,
                "assets": {path: digest(path) for path in ("dist/image.tar", "reports/application-sbom.cdx.json", "gl-sbom-report.cdx.json")}}
    write_json("reports/approval.json", approval)


def publish():
    approval = read_json("reports/approval.json")
    if approval["commit"] != required("CI_COMMIT_SHA") or approval["pipeline"] != required("CI_PIPELINE_ID"):
        raise ValueError("Approval belongs to another commit/pipeline")
    for path, expected in approval["assets"].items():
        if digest(path) != expected:
            raise ValueError(f"Approved artifact changed: {path}")
    repo = required("NEXUS_REPOSITORY")
    if not re.fullmatch(r"[a-zA-Z0-9_.-]+", repo):
        raise ValueError("Invalid Nexus raw repository name")
    api = API(required("NEXUS_URL"), auth=(required("NEXUS_USER"), required("NEXUS_PASSWORD")))
    prefix = f"/repository/{repo}/{int(required('CI_PROJECT_ID'))}/{required('CI_COMMIT_SHA')}/{int(required('CI_PIPELINE_ID'))}"
    for path in (*approval["assets"], "reports/approval.json"):
        target = f"{prefix}/{Path(path).name}"
        with Path(path).open("rb") as stream:
            api.request("PUT", target, data=stream, headers={"Content-Type": "application/octet-stream"})
        # Verify the actual stored bytes, not just the upload response.
        response = api.request("GET", target, stream=True)
        checksum = hashlib.sha256()
        for chunk in response.iter_content(1024 * 1024):
            checksum.update(chunk)
        if checksum.hexdigest() != digest(path):
            raise ValueError("Nexus stored artifact checksum mismatch")
        print(f"Nexus verified: {Path(path).name}")


def main():
    commands = {"audit": audit, "sonar-export": sonar_export, "gate": gate, "publish": publish,
                "validate-dependency-check": lambda: validate_dependency_check(read_json("reports/dependency-check-report.json"))}
    try:
        commands[sys.argv[1]]()
    except requests.RequestException as error:
        # InvalidHeader and transport exceptions may embed credentials in their
        # messages. Log only the class, never the submitted header/value.
        print(f"CI HTTP transport failed: {type(error).__name__}", file=sys.stderr)
        return 1
    except (KeyError, ValueError, RuntimeError, OSError, ElementTree.ParseError) as error:
        print(f"CI integration failed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
