#!/usr/bin/env python3
"""Prepare an isolated source snapshot; never copies local database/settings files."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("profile", choices=["django", "surfnews"])
parser.add_argument("destination", type=Path)
parser.add_argument("--source", type=Path, help="Required for Surfnews; source remains untouched")
args = parser.parse_args()
if args.destination.exists():
    parser.error("Destination already exists; choose a new empty path")
if args.profile == "surfnews" and not args.source:
    parser.error("Surfnews requires --source")
root = Path(__file__).resolve().parent.parent
args.destination.mkdir(parents=True)
shutil.copytree(root / args.profile, args.destination, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc", ".coverage", "coverage.xml"))
ci = args.destination / "ci"
ci.mkdir(exist_ok=True)
shutil.copy2(root / "security/pipeline.py", ci / "pipeline.py")
if args.profile == "surfnews":
    for filename in ("composer.json", "composer.lock"):
        shutil.copy2(args.source / filename, args.destination / filename)
    theme = Path("web/themes/aloha_surf")
    shutil.copytree(args.source / theme, args.destination / theme,
                    ignore=shutil.ignore_patterns(".DS_Store", "._*", "__pycache__"))
print(f"Prepared {args.profile} example: {args.destination}")
