#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

def should_be_package(dir_path: Path) -> bool:
    if dir_path.name == "__pycache__":
        return False
    if any(p.suffix == ".py" for p in dir_path.glob("*.py")):
        return True
    for sub in dir_path.iterdir():
        if sub.is_dir() and sub.name != "__pycache__":
            if should_be_package(sub):
                return True
    return False

def ensure_init(dir_path: Path, fix: bool) -> bool:
    init_file = dir_path / "__init__.py"
    if init_file.exists():
        return True
    if fix:
        init_file.write_text("")
        print(f"  + created: {init_file}")
        return True
    return False

def main():
    parser = argparse.ArgumentParser(description="Ensure Python package structure under src/")
    parser.add_argument("--src", default="src", help="src directory (default: src under project root)")
    parser.add_argument("--fix", action="store_true", help="create missing __init__.py files")
    args = parser.parse_args()

    # Resolve project root as the parent of this 'scripts' folder
    project_root = Path(__file__).resolve().parent.parent

    # If --src is absolute, use as-is; otherwise resolve relative to project root
    src_path = Path(args.src)
    root = src_path if src_path.is_absolute() else (project_root / src_path)
    root = root.resolve()

    if not root.exists():
        print(f"ERROR: src directory not found: {root}", file=sys.stderr)
        return 2

    print(f"Scanning under: {root}")

    missing = []
    for d in root.rglob("*"):
        if d.is_dir() and should_be_package(d):
            if not (d / "__init__.py").exists():
                missing.append(d)

    if not missing:
        print("✅ All good: package structure is consistent.")
        return 0

    print(f"Found {len(missing)} directories that should be packages but lack __init__.py")
    if args.fix:
        for d in missing:
            ensure_init(d, fix=True)
        print("✅ Fixed.")
        return 0
    else:
        for d in missing:
            print(f"  - missing: {d}/__init__.py")
        print("💡 Re-run with --fix to create them.")
        return 1

if __name__ == "__main__":
    sys.exit(main())