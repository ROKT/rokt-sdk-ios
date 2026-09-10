#!/usr/bin/env python3
"""Tests for the deterministic safe-change approval policy."""

from __future__ import annotations

import importlib.util
import json
import unittest
from copy import deepcopy
from pathlib import Path
from types import ModuleType
from typing import Any


SCRIPT_DIRECTORY = Path(__file__).parent


def _load_evaluator() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "evaluate_safe_change", SCRIPT_DIRECTORY / "evaluate_safe_change.py"
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load evaluator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


EVALUATOR = _load_evaluator()
with open(
    SCRIPT_DIRECTORY.parent / "safe-change-approval.json", encoding="utf-8"
) as policy_file:
    POLICY = json.load(policy_file)


def pull_request(**overrides: Any) -> dict[str, Any]:
    value: dict[str, Any] = {
        "state": "open",
        "draft": False,
        "base": {"ref": "main"},
        "head": {"sha": "abc123"},
        "user": {"login": "sdk-maintainer", "type": "User"},
        "author_association": "MEMBER",
        "changed_files": 1,
        "additions": 10,
        "deletions": 2,
    }
    value.update(overrides)
    return value


def changed_file(
    filename: str = "README.md", status: str = "modified"
) -> dict[str, str]:
    return {"filename": filename, "status": status, "patch": "@@ -1 +1 @@"}


def head_tree(
    filenames: tuple[str, ...] = ("README.md",), mode: str = "100644"
) -> dict[str, Any]:
    return {
        "truncated": False,
        "tree": [
            {"path": filename, "mode": mode, "type": "blob"}
            for filename in filenames
        ],
    }


class SafeChangeApprovalTests(unittest.TestCase):
    def evaluate(
        self,
        pr: dict[str, Any] | None = None,
        files: list[dict[str, Any]] | None = None,
        tree: dict[str, Any] | None = None,
        expected_head_sha: str = "abc123",
        policy: dict[str, Any] | None = None,
    ) -> tuple[bool, str]:
        return EVALUATOR.evaluate(
            policy or deepcopy(POLICY),
            pr or pull_request(),
            files or [changed_file()],
            tree or head_tree(),
            expected_head_sha,
        )

    def test_trusted_member_documentation_change_is_eligible(self) -> None:
        self.assertTrue(self.evaluate()[0])

    def test_dependabot_is_explicitly_trusted(self) -> None:
        pr = pull_request(
            user={"login": "dependabot[bot]", "type": "Bot"},
            author_association="CONTRIBUTOR",
        )
        self.assertTrue(self.evaluate(pr=pr)[0])

    def test_external_contributor_is_not_eligible(self) -> None:
        pr = pull_request(
            user={"login": "external-contributor", "type": "User"},
            author_association="CONTRIBUTOR",
        )
        self.assertFalse(self.evaluate(pr=pr)[0])

    def test_github_actions_cannot_approve_its_own_pull_request(self) -> None:
        pr = pull_request(
            user={"login": "github-actions[bot]", "type": "Bot"},
            author_association="MEMBER",
        )
        self.assertFalse(self.evaluate(pr=pr)[0])

    def test_unlisted_bot_is_not_trusted_by_member_association(self) -> None:
        pr = pull_request(
            user={"login": "some-app[bot]", "type": "Bot"},
            author_association="MEMBER",
        )
        self.assertFalse(self.evaluate(pr=pr)[0])

    def test_workflow_change_is_not_eligible(self) -> None:
        files = [changed_file(".github/workflows/pull-request.yml")]
        self.assertFalse(self.evaluate(files=files)[0])

    def test_nested_markdown_documentation_is_eligible(self) -> None:
        files = [changed_file("docs/guides/integration.md", "added")]
        tree = head_tree(("docs/guides/integration.md",))
        self.assertTrue(self.evaluate(files=files, tree=tree)[0])

    def test_non_markdown_file_in_docs_is_not_eligible(self) -> None:
        files = [changed_file("docs/example.swift", "added")]
        tree = head_tree(("docs/example.swift",))
        self.assertFalse(self.evaluate(files=files, tree=tree)[0])

    def test_sensitive_root_markdown_is_not_eligible(self) -> None:
        for filename in ("AGENTS.md", "CHANGELOG.md", "SECURITY.md"):
            with self.subTest(filename=filename):
                self.assertFalse(self.evaluate(files=[changed_file(filename)])[0])

    def test_mixed_safe_and_unsafe_change_is_not_eligible(self) -> None:
        pr = pull_request(changed_files=2)
        files = [changed_file(), changed_file("Package.swift")]
        tree = head_tree(("README.md", "Package.swift"))
        self.assertFalse(self.evaluate(pr=pr, files=files, tree=tree)[0])

    def test_renames_and_deletions_are_not_eligible(self) -> None:
        for status in ("renamed", "removed"):
            with self.subTest(status=status):
                self.assertFalse(
                    self.evaluate(files=[changed_file(status=status)])[0]
                )

    def test_draft_is_not_eligible(self) -> None:
        self.assertFalse(self.evaluate(pr=pull_request(draft=True))[0])

    def test_stale_validated_sha_is_not_eligible(self) -> None:
        self.assertFalse(self.evaluate(expected_head_sha="stale123")[0])

    def test_file_metadata_must_be_complete(self) -> None:
        self.assertFalse(
            self.evaluate(pr=pull_request(changed_files=2), files=[changed_file()])[0]
        )

    def test_binary_or_unpatchable_file_is_not_eligible(self) -> None:
        file = changed_file()
        del file["patch"]
        self.assertFalse(self.evaluate(files=[file])[0])

    def test_symlink_is_not_eligible(self) -> None:
        self.assertFalse(self.evaluate(tree=head_tree(mode="120000"))[0])

    def test_truncated_head_tree_is_not_eligible(self) -> None:
        tree = head_tree()
        tree["truncated"] = True
        self.assertFalse(self.evaluate(tree=tree)[0])

    def test_diff_limits_fail_closed(self) -> None:
        too_many_changes = pull_request(additions=1000, deletions=1)
        self.assertFalse(self.evaluate(pr=too_many_changes)[0])

        policy = deepcopy(POLICY)
        policy["max_changed_files"] = 1
        files = [changed_file(), changed_file("MIGRATING.md")]
        too_many_files = pull_request(changed_files=2)
        self.assertFalse(
            self.evaluate(
                pr=too_many_files,
                files=files,
                tree=head_tree(("README.md", "MIGRATING.md")),
                policy=policy,
            )[0]
        )

    def test_invalid_policy_fails_closed(self) -> None:
        policy = deepcopy(POLICY)
        policy["trusted_associations"] = []
        self.assertFalse(self.evaluate(policy=policy)[0])


if __name__ == "__main__":
    unittest.main()
