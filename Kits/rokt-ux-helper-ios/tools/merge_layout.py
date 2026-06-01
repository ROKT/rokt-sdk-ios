#!/usr/bin/env python3
"""Merge layout JSON files into experience.json.

Reads layout_variant.json and outer_layout.json, double-JSON-encodes them
(minify then JSON-string-wrap), and replaces the corresponding fields in
experience.json.

Usage:
    # Default paths (Example/Example/Resources/)
    python3 tools/merge_layout.py

    # Custom paths
    python3 tools/merge_layout.py --layout-variant path/to/layout_variant.json
    python3 tools/merge_layout.py --outer-layout path/to/outer_layout.json
    python3 tools/merge_layout.py --experience path/to/experience.json

    # Merge only one schema
    python3 tools/merge_layout.py --only layout-variant
    python3 tools/merge_layout.py --only outer-layout
"""

import argparse
import json
import os
import re
import sys


def find_repo_root():
    """Walk up from script location to find the repo root (contains Package.swift)."""
    path = os.path.dirname(os.path.abspath(__file__))
    while path != "/":
        if os.path.exists(os.path.join(path, "Package.swift")):
            return path
        path = os.path.dirname(path)
    return os.getcwd()


def embed_json(source_path):
    """Read a JSON file, minify it, and double-encode as a JSON string."""
    with open(source_path, "r") as f:
        data = json.load(f)
    return json.dumps(json.dumps(data, separators=(",", ":")))


def replace_field(content, field_name, encoded_value):
    """Replace a JSON field's value in the experience.json content.

    Matches the pattern: "fieldName": "..." (entire value on one line)
    and replaces just the value portion.
    """
    pattern = rf'("{field_name}":\s*)("(?:[^"\\]|\\.)*")'
    match = re.search(pattern, content)
    if not match:
        print(
            f"  ERROR: field '{field_name}' not found in experience.json",
            file=sys.stderr,
        )
        return content, False

    prefix = match.group(1)
    new_content = (
        content[: match.start()] + prefix + encoded_value + content[match.end() :]
    )
    return new_content, True


def main():
    repo_root = find_repo_root()
    resources = os.path.join(repo_root, "Example", "Example", "Resources")

    parser = argparse.ArgumentParser(
        description="Merge layout JSONs into experience.json"
    )
    parser.add_argument(
        "--experience",
        default=os.path.join(resources, "experience.json"),
        help="Path to experience.json (default: Example/Example/Resources/experience.json)",
    )
    parser.add_argument(
        "--layout-variant",
        default=os.path.join(resources, "layout_variant.json"),
        help="Path to layout_variant.json",
    )
    parser.add_argument(
        "--outer-layout",
        default=os.path.join(resources, "outer_layout.json"),
        help="Path to outer_layout.json",
    )
    parser.add_argument(
        "--only",
        choices=["layout-variant", "outer-layout"],
        help="Merge only one schema type",
    )
    args = parser.parse_args()

    with open(args.experience, "r") as f:
        content = f.read()

    merged = []

    if args.only != "outer-layout":
        if not os.path.exists(args.layout_variant):
            print(f"ERROR: {args.layout_variant} not found", file=sys.stderr)
            sys.exit(1)
        encoded = embed_json(args.layout_variant)
        content, ok = replace_field(content, "layoutVariantSchema", encoded)
        if ok:
            merged.append("layoutVariantSchema")

    if args.only != "layout-variant":
        if not os.path.exists(args.outer_layout):
            print(f"ERROR: {args.outer_layout} not found", file=sys.stderr)
            sys.exit(1)
        encoded = embed_json(args.outer_layout)
        content, ok = replace_field(content, "outerLayoutSchema", encoded)
        if ok:
            merged.append("outerLayoutSchema")

    if not merged:
        print("No fields were merged.", file=sys.stderr)
        sys.exit(1)

    with open(args.experience, "w") as f:
        f.write(content)

    print(
        f"Merged {', '.join(merged)} into {os.path.relpath(args.experience, repo_root)}"
    )


if __name__ == "__main__":
    main()
