"""Install the pinned platform-independent SonarScanner into .tools/sonar-scanner.

Run inside the C compilation job so its compiler, headers and JRE remain
available to analysis. The official ZIP must match SHA256 before extraction.
This does not install CFamily or grant a Sonar license; the preflight checks
that server prerequisite separately. Update VERSION and SHA256 together.
"""
import hashlib
import io
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "8.0.1.6346"
SHA256 = "8fbfb1eb546b734a60fc3e537108f06e389a8ca124fbab3a16236a8a51edcc15"
url = f"https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-{VERSION}.zip"
with urllib.request.urlopen(url, timeout=120) as response:
    payload = response.read()
if hashlib.sha256(payload).hexdigest() != SHA256:
    raise SystemExit("SonarScanner checksum mismatch")
folder = Path(".tools").resolve()
folder.mkdir(exist_ok=True)
with zipfile.ZipFile(io.BytesIO(payload)) as archive:
    if any(not (folder / name).resolve().is_relative_to(folder) for name in archive.namelist()):
        raise SystemExit("Unsafe archive path")
    archive.extractall(folder)
destination = folder / "sonar-scanner"
if destination.exists():
    shutil.rmtree(destination)
shutil.move(folder / f"sonar-scanner-{VERSION}", destination)
(destination / "bin/sonar-scanner").chmod(0o755)
