import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from agent_skills.cli import main
from agent_skills.workspace import WorkspaceError, init_workspace, load_workspace, remove_skill


class CliTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / ".git").mkdir()
        (self.root / "README.md").write_text("# test\n", encoding="utf-8")
        (self.root / "demo-skill").mkdir()
        (self.root / "demo-skill" / "SKILL.md").write_text(
            "---\nname: demo-skill\ndescription: >-\n  A test skill.\n---\n\n# Demo\n", encoding="utf-8"
        )
        self.old_cwd = os.getcwd()
        os.chdir(self.root)

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.temp.cleanup()

    def test_init_is_idempotent_and_writes_state(self):
        destination = self.root / "installed"
        self.assertEqual(main(["init", "--skills-dir", str(destination)]), 0)
        self.assertEqual(main(["init", "--skills-dir", str(destination)]), 0)
        config = json.loads((self.root / ".agent-skills" / "config.json").read_text())
        manifest = json.loads((self.root / ".agent-skills" / "manifest.json").read_text())
        self.assertEqual(Path(config["skills_dir"]), destination.resolve())
        self.assertEqual(manifest["skills"], [])

    def test_create_generates_valid_scaffold_and_refuses_overwrite(self):
        self.assertEqual(main(["create", "new-skill"]), 0)
        skill_file = self.root / "new-skill" / "SKILL.md"
        self.assertTrue(skill_file.exists())
        self.assertNotEqual(main(["create", "new-skill"]), 0)
        self.assertNotEqual(main(["create", "Bad_Name"]), 0)

    def test_list_is_read_only_and_reflects_add_remove(self):
        self.assertEqual(main(["list"]), 0)
        destination = self.root / "installed"
        main(["init", "--skills-dir", str(destination)])
        self.assertEqual(main(["list"]), 0)
        main(["add", "demo-skill"])
        self.assertTrue((destination / "demo-skill" / "SKILL.md").exists())
        main(["list"])
        main(["remove", "demo-skill"])
        self.assertFalse((destination / "demo-skill").exists())

    def test_add_duplicate_is_safe_and_remove_missing_is_safe(self):
        destination = self.root / "installed"
        main(["init", "--skills-dir", str(destination)])
        self.assertEqual(main(["add", "demo-skill"]), 0)
        self.assertEqual(main(["add", "demo-skill"]), 0)
        self.assertEqual(main(["remove", "demo-skill"]), 0)
        self.assertEqual(main(["remove", "demo-skill"]), 0)

    def test_remove_refuses_modified_copy_without_force(self):
        destination = self.root / "installed"
        main(["init", "--skills-dir", str(destination)])
        main(["add", "demo-skill"])
        (destination / "demo-skill" / "local.txt").write_text("keep", encoding="utf-8")
        self.assertEqual(main(["remove", "demo-skill"]), 1)
        self.assertTrue((destination / "demo-skill").exists())
        self.assertEqual(main(["remove", "demo-skill", "--force"]), 0)

    def test_remove_does_not_delete_unmanaged_directory(self):
        destination = self.root / "installed"
        destination.mkdir()
        (destination / "unmanaged").mkdir()
        workspace, _ = init_workspace(self.root, destination)
        self.assertEqual(remove_skill(workspace, "unmanaged"), "not added")
        self.assertTrue((destination / "unmanaged").exists())

    def test_invalid_add_and_uninitialized_mutation_fail(self):
        self.assertEqual(main(["add", "missing-skill"]), 1)
        self.assertEqual(main(["remove", "demo-skill"]), 1)


if __name__ == "__main__":
    unittest.main()
