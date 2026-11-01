#!/usr/bin/env python3
"""Create a generic CI overlay in a new directory; never copies application code."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("profile", choices=["django", "angular", "angular-java"])
parser.add_argument("destination", type=Path, help="New directory for the CI overlay")
args = parser.parse_args()
if args.destination.exists():
    parser.error("Destination already exists; choose a new empty path")
root = Path(__file__).resolve().parent.parent
shutil.copytree(root / args.profile, args.destination,
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".coverage", "coverage.xml"))
ci = args.destination / "ci"
ci.mkdir(exist_ok=True)
shutil.copy2(root / "security/pipeline.py", ci / "pipeline.py")
print(f"Prepared {args.profile} CI overlay: {args.destination}")
print("Merge this overlay into your application repository and follow the root README.")
