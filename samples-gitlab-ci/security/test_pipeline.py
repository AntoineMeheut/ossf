import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import io
from contextlib import redirect_stderr
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location("pipeline", Path(__file__).with_name("pipeline.py"))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class GateTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.old_cwd = Path.cwd()
        os.chdir(self.folder.name)
        self.env = patch.dict(os.environ, {
            "CI_COMMIT_SHA": "a" * 40, "CI_PROJECT_ID": "1", "CI_PIPELINE_ID": "2", "CI_JOB_ID": "3",
            "DEFECTDOJO_URL": "http://dojo.invalid", "DEFECTDOJO_TOKEN": "test-only-placeholder",
            "DEFECTDOJO_PRODUCT_ID": "1", "OSSF_PROFILE": "django", "DD_MIN_SEVERITY": "High",
        })
        self.env.start()
        for filename, _, key in p.REPORTS:
            if filename.endswith(".xml"):
                Path(filename).parent.mkdir(parents=True, exist_ok=True)
                Path(filename).write_text("<analysis><dependencies><dependency/></dependencies></analysis>")
                p.write_json("reports/dependency-check-report.json", {"dependencies": [{"name": "example"}]})
                continue
            data = {key: [], "scan": {"status": "success"}}
            if key == "components":
                data.update(bomFormat="CycloneDX", components=[{"name": "example"}])
            if key == "dependencies":
                data[key] = [{"name": "example", "version": "1", "vulns": []}]
            p.write_json(filename, data)
        p.write_json("reports/sonar-quality-gate.json", {"commit": "a" * 40, "projectStatus": {"status": "OK"}})
        Path("dist").mkdir()
        Path("dist/image.tar").write_bytes(b"unit-test-artifact")
        self.api = MagicMock()
        self.api.json.side_effect = self.response
        self.finding = None

    def tearDown(self):
        self.env.stop()
        os.chdir(self.old_cwd)
        self.folder.cleanup()

    def response(self, method, path, **kwargs):
        if path == "/api/v2/engagements/":
            return {"id": 7}
        if path == "/api/v2/import-scan/":
            return {"test_id": 1, "deduplication_complete": True}
        return {"count": int(self.finding is not None), "results": [self.finding] if self.finding else [], "next": None}

    def run_gate(self):
        with patch.object(p, "API", return_value=self.api):
            p.gate()

    def test_complete_clean_scan_approves_exact_artifact(self):
        self.run_gate()
        approval = p.read_json("reports/approval.json")
        self.assertEqual(approval["assets"]["dist/image.tar"], p.digest("dist/image.tar"))
        self.assertEqual(len(approval["tests"]), len(p.REPORTS))

    def test_missing_scan_never_creates_context_or_approval(self):
        Path("gl-sast-report.json").unlink()
        with self.assertRaises(OSError):
            self.run_gate()
        self.api.json.assert_not_called()
        self.assertFalse(Path("reports/approval.json").exists())

    def test_scanner_failure_is_not_a_clean_report(self):
        p.write_json("gl-sast-report.json", {"vulnerabilities": [], "scan": {"status": "failure"}})
        with self.assertRaises(ValueError):
            self.run_gate()

    def test_unverified_high_finding_blocks_publication(self):
        self.finding = {"id": 9, "severity": "High", "active": True, "verified": False}
        with self.assertRaises(ValueError):
            self.run_gate()
        self.assertFalse(Path("reports/approval.json").exists())

    def test_sonar_failure_blocks_after_all_imports(self):
        p.write_json("reports/sonar-quality-gate.json", {"commit": "a" * 40, "projectStatus": {"status": "ERROR"}})
        with self.assertRaises(ValueError):
            self.run_gate()
        self.assertEqual(len([call for call in self.api.json.call_args_list if call.args[1] == "/api/v2/import-scan/"]), len(p.REPORTS))

    def test_async_import_cannot_approve_before_deduplication(self):
        self.api.json.side_effect = [{"id": 7}, {"test_id": 1, "deduplication_complete": False}]
        with self.assertRaises(ValueError):
            self.run_gate()

    def test_unknown_severity_blocks(self):
        self.finding = {"id": 9, "severity": "Unknown", "active": True}
        with self.assertRaises(ValueError):
            self.run_gate()

    def test_unknown_scanner_severity_cannot_be_downgraded_by_importer(self):
        p.write_json("gl-sast-report.json", {"vulnerabilities": [{"severity": "Unknown"}], "scan": {"status": "success"}})
        with self.assertRaises(ValueError):
            self.run_gate()
        self.assertEqual(p.read_json("reports/gate-summary.json")["unknown_scanner_severities"], 1)

    def test_dependency_check_analysis_error_blocks(self):
        p.write_json("reports/dependency-check-report.json", {"dependencies": [{}], "scanInfo": {"analysisExceptions": ["update failed"]}})
        with self.assertRaises(ValueError):
            self.run_gate()

    def test_incomplete_dependency_check_xml_blocks(self):
        Path("reports/dependency-check-report.xml").write_text("<analysis><dependencies/></analysis>")
        with self.assertRaises(ValueError):
            self.run_gate()

    def test_dependency_advisory_without_severity_still_blocks(self):
        p.write_json("reports/pip-audit.json", {"dependencies": [{"name": "example", "vulns": [{"id": "test-advisory"}]}]})
        with self.assertRaises(ValueError):
            self.run_gate()
        self.assertFalse(Path("reports/approval.json").exists())

    def test_composer_profile_requires_its_own_audit(self):
        with patch.dict(os.environ, {"OSSF_PROFILE": "surfnews"}):
            with self.assertRaises(OSError):
                self.run_gate()
            p.write_json("reports/composer-audit.json", {"advisories": {}})
            self.run_gate()

    def test_tampered_artifact_is_never_uploaded(self):
        self.run_gate()
        Path("dist/image.tar").write_bytes(b"changed")
        with patch.object(p, "API") as api, self.assertRaises(ValueError):
            p.publish()
        api.assert_not_called()

    def test_publisher_uploads_the_approved_bytes_and_checks_readback(self):
        self.run_gate()
        stored = {}
        api = MagicMock()

        def transfer(method, target, **kwargs):
            response = MagicMock()
            if method == "PUT":
                stored[target] = kwargs["data"].read()
            else:
                response.iter_content.return_value = [stored[target]]
            return response

        api.request.side_effect = transfer
        with patch.dict(os.environ, {"NEXUS_URL": "https://nexus.invalid", "NEXUS_USER": "test",
                                     "NEXUS_PASSWORD": "test-only-placeholder", "NEXUS_REPOSITORY": "ci"}), \
                patch.object(p, "API", return_value=api):
            p.publish()
        self.assertEqual(len(stored), 4)
        self.assertIn(b"unit-test-artifact", stored.values())

    def test_incomplete_pagination_blocks(self):
        api = MagicMock()
        api.json.return_value = {"count": 2, "results": [{"id": 1}], "next": None}
        with self.assertRaises(ValueError):
            p.findings(api, 7)

    def test_cross_origin_pagination_cannot_receive_token(self):
        api = p.API("https://dojo.invalid", token="test-only-placeholder")
        with patch.object(api.session, "request") as request, self.assertRaises(ValueError):
            api.request("GET", "https://another.invalid/findings")
        request.assert_not_called()

    def test_transport_exception_cannot_print_a_token(self):
        output = io.StringIO()
        with patch.object(p, "gate", side_effect=p.requests.exceptions.InvalidHeader("secret-in-header")), \
                patch.object(p.sys, "argv", ["pipeline.py", "gate"]), redirect_stderr(output):
            self.assertEqual(p.main(), 1)
        self.assertNotIn("secret-in-header", output.getvalue())


if __name__ == "__main__":
    unittest.main()
