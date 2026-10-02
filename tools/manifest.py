#!/usr/bin/env python3
"""Write or check addons/shanty/MANIFEST.sha256.

The manifest lists the SHA-256 of every file under addons/shanty/, sorted by
path, one `<hash>  <path>` line each (the `sha256sum` format), LF line endings.
It leaves out what Godot writes on import -- `*.uid`, `*.import`,
`*.translation` and anything under a `.godot` folder -- and the manifest itself.
Paths are relative to addons/shanty/ and use forward slashes.

    python tools/manifest.py           rewrite the manifest
    python tools/manifest.py --check   exit 1, naming each difference, unless the file
                                       is byte-for-byte what the generator writes

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


def _parse(text: str) -> list[tuple[str, str]]:
    """(path, digest) for every line, in file order, duplicates and all."""
    entries: list[tuple[str, str]] = []
    for line in text.split("\n"):
        if line:
            digest, _, path = line.partition("  ")
            entries.append((path, digest))
    return entries


def compare(recorded: bytes, expected: bytes) -> list[str]:
    """Every way `recorded` differs from `expected`; empty only when the bytes are equal.

    The file must be exactly what the generator writes, so anything that would
    pass a looser reading -- reordered, duplicated or blank lines, CR line
    endings, a missing final newline -- is still a difference, named here.
    """
    if recorded == expected:
        return []
    problems: list[str] = []
    try:
        recorded_text = recorded.decode("utf-8")
    except UnicodeDecodeError:
        return [f"{MANIFEST_NAME} is not UTF-8"]
    if "\r" in recorded_text:
        problems.append(f"{MANIFEST_NAME} has CR line endings; it must be LF only")
        recorded_text = recorded_text.replace("\r", "")
    rows = _parse(recorded_text)
    wanted = _parse(expected.decode("utf-8"))
    recorded_digests: dict[str, str] = {}
    for path, digest in rows:
        if path in recorded_digests:
            problems.append(f"duplicate: {path}")
        recorded_digests[path] = digest
    wanted_digests = dict(wanted)
    for path in sorted(set(recorded_digests) | set(wanted_digests)):
        if path not in wanted_digests:
            problems.append(f"listed but missing: {path}")
        elif path not in recorded_digests:
            problems.append(f"not listed: {path}")
        elif recorded_digests[path] != wanted_digests[path]:
            problems.append(f"changed: {path}")
    if not problems:
        recorded_order = [path for path, _ in rows]
        if recorded_order != [path for path, _ in wanted]:
            problems.append("out of order: entries must be sorted by path")
    if not problems:
        problems.append(
            f"{MANIFEST_NAME} differs from the generated text in whitespace"
            " (blank lines, separators or the final newline)"
        )
    return problems


def check(addon: pathlib.Path = ADDON) -> list[str]:
    """Every difference between the manifest on disk and the addon; empty when current."""
    manifest = addon / MANIFEST_NAME
    if not manifest.is_file():
        return [f"{MANIFEST_NAME} is missing; run tools/manifest.py"]
    return compare(manifest.read_bytes(), build(addon).encode("utf-8"))


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
