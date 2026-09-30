#!/usr/bin/env python3
"""Evaluate whether a pull request is eligible for deterministic approval."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import PurePosixPath
from typing import Any


def _is_non_empty_string_list(value: Any) -> bool:
    return (
        isinstance(value, list)
        and bool(value)
        and all(isinstance(item, str) and bool(item) for item in value)
    )


def validate_policy(policy: dict[str, Any]) -> None:
    """Reject malformed policy instead of accidentally broadening approval."""
    required_string_lists = (
        "base_branches",
        "trusted_actors",
        "trusted_associations",
        "excluded_actors",
        "allowed_files",
        "allowed_statuses",
    )
    if policy.get("version") != 1:
        raise ValueError("unsupported policy version")

    for field in required_string_lists:
        if not _is_non_empty_string_list(policy.get(field)):
            raise ValueError(f"invalid policy field: {field}")

    for field in ("max_changed_files", "max_total_changes"):
        if not isinstance(policy.get(field), int) or policy[field] <= 0:
            raise ValueError(f"invalid policy field: {field}")

    directories = policy.get("allowed_directories")
    if not isinstance(directories, list) or not directories:
        raise ValueError("invalid policy field: allowed_directories")

    for directory in directories:
        if not isinstance(directory, dict):
            raise ValueError("invalid allowed directory")
        path = directory.get("path")
        extensions = directory.get("extensions")
        if (
            not isinstance(path, str)
            or not path.endswith("/")
            or path.startswith("/")
            or ".." in PurePosixPath(path).parts
            or not _is_non_empty_string_list(extensions)
            or any(not extension.startswith(".") for extension in extensions)
        ):
            raise ValueError("invalid allowed directory")


def _is_allowed_path(filename: str, policy: dict[str, Any]) -> bool:
    if filename.startswith("/") or ".." in PurePosixPath(filename).parts:
        return False

    if filename in policy["allowed_files"]:
        return True

    for directory in policy["allowed_directories"]:
        if filename.startswith(directory["path"]) and any(
            filename.endswith(extension) for extension in directory["extensions"]
        ):
            return True

    return False


def evaluate(
    policy: dict[str, Any],
    pull_request: dict[str, Any],
    files: list[dict[str, Any]],
    head_tree: dict[str, Any],
    expected_head_sha: str,
) -> tuple[bool, str]:
    """Return an eligibility decision and a non-sensitive reason."""
    try:
        validate_policy(policy)
    except ValueError:
        return False, "the approval policy is invalid"

    if pull_request.get("state") != "open":
        return False, "the pull request is not open"
    if pull_request.get("draft") is not False:
        return False, "draft pull requests are not eligible"

    base = pull_request.get("base")
    if not isinstance(base, dict) or base.get("ref") not in policy["base_branches"]:
        return False, "the base branch is not eligible"

    head = pull_request.get("head")
    if (
        not expected_head_sha
        or not isinstance(head, dict)
        or head.get("sha") != expected_head_sha
    ):
        return False, "the validated commit is not the current pull request head"

    user = pull_request.get("user")
    actor = user.get("login") if isinstance(user, dict) else None
    actor_type = user.get("type") if isinstance(user, dict) else None
    association = pull_request.get("author_association")
    if not isinstance(actor, str) or actor in policy["excluded_actors"]:
        return False, "the pull request author is not eligible"
    if (
        actor not in policy["trusted_actors"]
        and (
            actor_type != "User"
            or association not in policy["trusted_associations"]
        )
    ):
        return False, "the pull request author is not trusted by this policy"

    changed_files = pull_request.get("changed_files")
    additions = pull_request.get("additions")
    deletions = pull_request.get("deletions")
    if (
        not isinstance(changed_files, int)
        or not isinstance(additions, int)
        or not isinstance(deletions, int)
        or changed_files <= 0
        or len(files) != changed_files
    ):
        return False, "the changed-file metadata is incomplete"
    if changed_files > policy["max_changed_files"]:
        return False, "the pull request exceeds the changed-file limit"
    if additions + deletions > policy["max_total_changes"]:
        return False, "the pull request exceeds the total-change limit"

    if head_tree.get("truncated") is not False or not isinstance(
        head_tree.get("tree"), list
    ):
        return False, "the head tree metadata is incomplete"

    tree_entries: dict[str, dict[str, Any]] = {}
    for entry in head_tree["tree"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            return False, "the head tree metadata is invalid"
        if entry["path"] in tree_entries:
            return False, "the head tree metadata is invalid"
        tree_entries[entry["path"]] = entry

    seen_filenames: set[str] = set()
    for file in files:
        if not isinstance(file, dict):
            return False, "the changed-file metadata is invalid"
        filename = file.get("filename")
        status = file.get("status")
        if not isinstance(filename, str) or filename in seen_filenames:
            return False, "the changed-file metadata is invalid"
        seen_filenames.add(filename)
        if status not in policy["allowed_statuses"]:
            return False, "a file operation is not eligible"
        if not _is_allowed_path(filename, policy):
            return False, "a changed file is outside the safe path set"
        if not isinstance(file.get("patch"), str) or not file["patch"]:
            return False, "a changed file does not have a textual patch"

        tree_entry = tree_entries.get(filename)
        if (
            not tree_entry
            or tree_entry.get("type") != "blob"
            or tree_entry.get("mode") not in ("100644", "100755")
        ):
            return False, "a changed file is not a regular file"

    return True, "trusted author, safe paths, bounded diff, and current validated commit"


def _load_json(path: str) -> Any:
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def _write_github_output(path: str, eligible: bool, reason: str) -> None:
    with open(path, "a", encoding="utf-8") as output:
        output.write(f"eligible={'true' if eligible else 'false'}\n")
        output.write(f"reason={reason}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--policy", required=True)
    parser.add_argument("--pull-request", required=True)
    parser.add_argument("--files", required=True)
    parser.add_argument("--head-tree", required=True)
    parser.add_argument("--expected-head-sha", required=True)
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    args = parser.parse_args()

    try:
        policy = _load_json(args.policy)
        pull_request = _load_json(args.pull_request)
        files = _load_json(args.files)
        head_tree = _load_json(args.head_tree)
        if not isinstance(policy, dict) or not isinstance(pull_request, dict):
            raise ValueError("unexpected JSON shape")
        if not isinstance(files, list) or not isinstance(head_tree, dict):
            raise ValueError("unexpected GitHub JSON shape")
        eligible, reason = evaluate(
            policy, pull_request, files, head_tree, args.expected_head_sha
        )
    except (OSError, json.JSONDecodeError, ValueError, TypeError):
        eligible, reason = False, "the pull request metadata could not be evaluated"

    if args.github_output:
        _write_github_output(args.github_output, eligible, reason)
    print(f"eligible={str(eligible).lower()} reason={reason}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
