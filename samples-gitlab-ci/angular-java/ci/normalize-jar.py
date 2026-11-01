"""Stage one executable Maven JAR without guessing between build artifacts.

Run after backend tests from the repository root with BACKEND_JAR_GLOB set.
The output is .ci-dist/backend/application.jar, shared by the image and approval.
Main-Class validation does not replace the runtime HTTP smoke check.
"""
import glob
import os
from pathlib import Path
import shutil
import zipfile

paths = [Path(p) for p in glob.glob(os.environ["BACKEND_JAR_GLOB"])]
paths = [p for p in paths if not p.name.endswith(("-sources.jar", "-javadoc.jar", "-tests.jar"))]
if len(paths) != 1:
    raise SystemExit("BACKEND_JAR_GLOB must select exactly one executable JAR")
with zipfile.ZipFile(paths[0]) as jar:
    manifest = jar.read("META-INF/MANIFEST.MF").decode()
    if "Main-Class:" not in manifest:
        raise SystemExit("Selected JAR has no Main-Class; configure an executable/fat JAR")
destination = Path(".ci-dist/backend/application.jar")
destination.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(paths[0], destination)
