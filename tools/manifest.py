#!/usr/bin/env python3
"""Write or check addons/shanty/MANIFEST.sha256.

The manifest lists the SHA-256 of every file under addons/shanty/, sorted by
path, one `<hash>  <path>` line each (the `sha256sum` format), LF line endings.
It leaves out what Godot writes on import -- `*.uid`, `*.import`,
`*.translation` and anything under a `.godot` folder -- and the manifest itself.
Paths are relative to addons/shanty/ and use forward slashes.

    python tools/manifest.py           rewrite the manifest
    python tools/manifest.py --check   exit 1, naming each difference, if it is stale

Standard library only.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import sys

ADDON = pathlib.Path(__file__).resolve().parent.parent / "addons" / "shanty"
MANIFEST_NAME = "MANIFEST.sha256"
IGNORED_SUFFIXES = (".uid", ".import", ".translation")


def _is_listed(relative: pathlib.PurePosixPath) -> bool:
    if relative.as_posix() == MANIFEST_NAME:
        return False
    if ".godot" in relative.parts:
        return False
    return not relative.name.endswith(IGNORED_SUFFIXES)


def _digest(path: pathlib.Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            sha.update(block)
    return sha.hexdigest()


def build(addon: pathlib.Path = ADDON) -> str:
    """The manifest's full text for the addon as it is on disk."""
    lines: list[str] = []
    for path in sorted(addon.rglob("*")):
        if not path.is_file():
            continue
        relative = pathlib.PurePosixPath(path.relative_to(addon).as_posix())
        if _is_listed(relative):
            lines.append(f"{_digest(path)}  {relative.as_posix()}")
    lines.sort(key=lambda line: line.split("  ", 1)[1])
    return "\n".join(lines) + "\n"


def _entries(text: str) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in text.splitlines():
        if line.strip():
            digest, _, path = line.partition("  ")
            entries[path] = digest
    return entries


def check(addon: pathlib.Path = ADDON) -> list[str]:
    """Every difference between the manifest on disk and the addon; empty when current."""
    manifest = addon / MANIFEST_NAME
    if not manifest.is_file():
        return [f"{MANIFEST_NAME} is missing; run tools/manifest.py"]
    recorded_text = manifest.read_bytes().decode("utf-8")
    problems: list[str] = []
    if "\r" in recorded_text:
        problems.append(f"{MANIFEST_NAME} has CR line endings; it must be LF only")
    recorded = _entries(recorded_text)
    actual = _entries(build(addon))
    for path in sorted(set(recorded) | set(actual)):
        if path not in actual:
            problems.append(f"listed but missing: {path}")
        elif path not in recorded:
            problems.append(f"not listed: {path}")
        elif recorded[path] != actual[path]:
            problems.append(f"changed: {path}")
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="verify instead of writing")
    args = parser.parse_args(argv)
    if args.check:
        problems = check()
        for problem in problems:
            print(problem)
        if problems:
            print(f"{MANIFEST_NAME} is stale: run python tools/manifest.py")
            return 1
        print(f"{MANIFEST_NAME} matches addons/shanty/.")
        return 0
    (ADDON / MANIFEST_NAME).write_bytes(build().encode("utf-8"))
    print(f"Wrote {MANIFEST_NAME}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
