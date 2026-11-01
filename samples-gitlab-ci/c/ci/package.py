"""Normalize tested artifacts for Docker packaging and Nexus approval.

Run ``python ci/package.py python|java|c`` from the consuming repository root.
Python preserves the sole wheel's valid filename inside python-package.tar.gz;
Java uses JAVA_JAR_GLOB and requires one executable manifest; C packages the
staged /usr/local tree after checking C_EXECUTABLE. Existing build/test outputs
are inputs: this script does not compile, test or publish application code.
"""
import glob
import os
from pathlib import Path
import shutil
import sys
import tarfile
import zipfile

profile = sys.argv[1]
Path('dist').mkdir(exist_ok=True)
if profile == 'python':
    wheels = list(Path('dist/wheels').glob('*.whl'))
    if len(wheels) != 1:
        raise SystemExit('Expected exactly one project wheel in dist/wheels')
    target = Path('.ci-dist/wheels'); target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(wheels[0], target / wheels[0].name)
    with tarfile.open('dist/python-package.tar.gz', 'w:gz') as archive:
        archive.add(wheels[0], arcname=wheels[0].name)
elif profile == 'java':
    jars = [Path(p) for p in glob.glob(os.environ['JAVA_JAR_GLOB'])
            if not p.endswith(('-sources.jar', '-javadoc.jar', '-tests.jar'))]
    if len(jars) != 1:
        raise SystemExit('JAVA_JAR_GLOB must select exactly one executable JAR')
    with zipfile.ZipFile(jars[0]) as jar:
        if 'Main-Class:' not in jar.read('META-INF/MANIFEST.MF').decode():
            raise SystemExit('Selected JAR has no Main-Class')
    shutil.copy2(jars[0], 'dist/application.jar')
elif profile == 'c':
    path = os.environ['C_EXECUTABLE']
    if not path.startswith('/usr/local/') or '..' in Path(path).parts:
        raise SystemExit('C_EXECUTABLE must be an absolute installed path under /usr/local')
    binary = Path('.ci-dist') / path.lstrip('/')
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise SystemExit('CMake install did not produce C_EXECUTABLE')
    with tarfile.open('dist/c-package.tar.gz', 'w:gz') as archive:
        archive.add('.ci-dist/usr', arcname='usr')
else:
    raise SystemExit('Unknown package profile')
