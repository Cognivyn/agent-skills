import json
import os
import tempfile
import unittest
from pathlib import Path

from agent_skills.cli import main
from agent_skills.validation import _dependencies, _field, validate_skill_report
from agent_skills.workspace import WorkspaceError, init_workspace


class ValidationTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / ".git").mkdir()
        (self.root / "README.md").write_text("# test\n", encoding="utf-8")
        (self.root / "demo-skill").mkdir()
        (self.root / "demo-skill" / "SKILL.md").write_text(
            "---\nname: demo-skill\ndescription: >-\n  A test skill.\n---\n\n# Demo\n",
            encoding="utf-8",
        )
        self.old_cwd = os.getcwd()
        os.chdir(self.root)

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.temp.cleanup()

    def test_folded_scalar_description_parsing(self):
        frontmatter = "name: test-folded\ndescription: >-\n  Line 1 of folded description.\n  Line 2 of folded description."
        desc = _field(frontmatter, "description")
        self.assertEqual(desc, "Line 1 of folded description. Line 2 of folded description.")

        frontmatter_pipe = "name: test-pipe\ndescription: |\n  Line A\n  Line B"
        desc_pipe = _field(frontmatter_pipe, "description")
        self.assertEqual(desc_pipe, "Line A Line B")

    def test_inline_list_and_block_list_dependencies(self):
        inline_fm = "name: inline-skill\ndescription: desc\nmetadata:\n  dependencies: [demo-skill, other-skill]\n"
        deps_inline, errs_inline = _dependencies(inline_fm)
        self.assertEqual(errs_inline, [])
        self.assertEqual(deps_inline, ["demo-skill", "other-skill"])

        block_fm = "name: block-skill\ndescription: desc\nmetadata:\n  dependencies:\n    - demo-skill\n    - other-skill\n"
        deps_block, errs_block = _dependencies(block_fm)
        self.assertEqual(errs_block, [])
        self.assertEqual(deps_block, ["demo-skill", "other-skill"])

    def test_add_link_flow(self):
        installed = self.root / "installed"
        main(["init", "--skills-dir", str(installed)])
        self.assertEqual(main(["add", "demo-skill", "--link"]), 0)
        dest = installed / "demo-skill"
        self.assertTrue(dest.is_symlink())
        manifest = json.loads((self.root / ".agent-skills" / "manifest.json").read_text())
        self.assertIn("demo-skill", manifest["skills"])

    def test_create_with_directory(self):
        custom_dir = self.root / "custom_location"
        custom_dir.mkdir()
        self.assertEqual(main(["create", "custom-skill", "--directory", str(custom_dir)]), 0)
        skill_file = custom_dir / "custom-skill" / "SKILL.md"
        self.assertTrue(skill_file.exists())
        # verify root docs companion was NOT created since --directory was provided
        self.assertFalse((self.root / "docs" / "skills" / "custom-skill" / "README.md").exists())

    def test_init_skills_dir_conflict_branch(self):
        dir1 = self.root / "installed1"
        dir2 = self.root / "installed2"
        init_workspace(self.root, dir1)
        with self.assertRaises(WorkspaceError) as ctx:
            init_workspace(self.root, dir2)
        self.assertIn("workspace already points to", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
