"""Regression tests for an installed Implib.so distribution."""

import os
from pathlib import Path
import subprocess
import sys
import sysconfig
import tempfile
import unittest

import implib_so


TARGETS = (
    "aarch64",
    "arm",
    "e2k",
    "i386",
    "mips",
    "mips64",
    "powerpc64",
    "powerpc64le",
    "riscv64",
    "x86_64",
)


@unittest.skipUnless(os.name == "posix", "Implib.so requires a POSIX host.")
class InstalledPackageTests(unittest.TestCase):
    """Exercise installed commands without relying on the checkout directory."""

    def setUp(self):
        """Keep directory cleanup registered for the entire test's lifetime."""
        workdir = tempfile.TemporaryDirectory(  # pylint: disable=consider-using-with
            prefix="implib-so-test-"
        )
        self.addCleanup(workdir.cleanup)
        self.directory = Path(workdir.name)
        self.script_directory = Path(sysconfig.get_path("scripts"))
        self.definition = self.directory / "fixture.def"
        self.definition.write_text(
            "LIBRARY libfixture.so\nEXPORTS\n  fixture_value\n",
            encoding="utf-8",
        )

    def run_command(self, *args, expected_returncode=0):
        """Report captured diagnostics for an unexpected subprocess status."""
        result = subprocess.run(
            [str(arg) for arg in args],
            cwd=str(self.directory),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=False,
        )
        self.assertEqual(
            result.returncode,
            expected_returncode,
            result.stdout + result.stderr,
        )
        return result

    def test_installed_resources(self):
        """Require the full runtime manifest from the installed package."""
        root = Path(implib_so.__file__).resolve().parent
        checkout = Path(__file__).resolve().parent.parent
        self.assertNotEqual(root, checkout)
        self.assertTrue((root / "implib-gen.py").is_file())
        self.assertTrue((root / "arch" / "common" / "init.c.tpl").is_file())
        self.assertEqual(
            {path.name for path in (root / "arch").iterdir() if path.is_dir()},
            set(TARGETS) | {"common"},
        )
        for target in TARGETS:
            for name in ("config.ini", "table.S.tpl", "trampoline.S.tpl"):
                with self.subTest(target=target, name=name):
                    self.assertTrue((root / "arch" / target / name).is_file())

    def test_entry_points(self):
        """Expose the original generator options through every invocation."""
        commands = [
            [sys.executable, "-m", "implib_so"],
            [self.script_directory / "implib-gen"],
            [self.script_directory / "implib-gen.py"],
        ]
        for command in commands:
            with self.subTest(command=command):
                result = self.run_command(*command, "--help")
                self.assertIn("Generate wrappers for shared library functions.", result.stdout)
                self.assertIn("--symbol-prefix", result.stdout)

    def test_def_generation_matches_source_for_every_target(self):
        """Installation must preserve output from every architecture template."""
        source = Path(__file__).resolve().parent.parent / "implib-gen.py"
        for target in TARGETS:
            with self.subTest(target=target):
                arguments = [
                    "--quiet",
                    "--target",
                    target,
                    "--symbol-prefix",
                    "wrapped_",
                    self.definition,
                ]
                self.run_command(
                    sys.executable, source, *arguments, "--outdir", "source"
                )
                self.run_command(
                    sys.executable, "-m", "implib_so",
                    *arguments, "--outdir", "installed",
                )
                for suffix in ("tramp.S", "init.c"):
                    name = "fixture." + suffix
                    original = (self.directory / "source" / name).read_bytes()
                    installed = (self.directory / "installed" / name).read_bytes()
                    self.assertEqual(installed, original)
                    if suffix == "tramp.S":
                        self.assertIn(b"wrapped_fixture_value", installed)

    def test_generated_elf_wrapper_runs(self):
        """Resolve a shared-library function at runtime without linking it."""
        compiler = os.environ.get("CC", "cc")
        library = self.directory / "libfixture.so"
        (self.directory / "fixture.c").write_text(
            "int fixture_value(void) { return 42; }\n", encoding="utf-8"
        )
        (self.directory / "main.c").write_text(
            "int fixture_value(void);\n"
            "int main(void) { return fixture_value() != 42; }\n",
            encoding="utf-8",
        )
        self.run_command(
            compiler, "-shared", "-fPIC", "fixture.c", "-o", library
        )
        self.run_command(
            self.script_directory / "implib-gen",
            "--quiet", "--library-load-name", library, library,
        )
        executable = self.directory / "fixture"
        self.run_command(
            compiler, "main.c", "libfixture.so.tramp.S", "libfixture.so.init.c",
            "-ldl", "-pthread", "-o", executable,
        )
        dynamic = self.run_command("readelf", "-d", executable)
        self.assertNotIn("Shared library: [libfixture.so]", dynamic.stdout)
        self.run_command(executable)

    def test_invalid_arguments_fail(self):
        """Preserve nonzero statuses and diagnostics for invalid invocations."""
        result = self.run_command(
            sys.executable, "-m", "implib_so",
            "--target", "not-an-architecture", self.definition,
            expected_returncode=1,
        )
        self.assertIn("unknown architecture 'not'", result.stderr)
        result = self.run_command(
            sys.executable, "-m", "implib_so", expected_returncode=2
        )
        self.assertIn("the following arguments are required: LIB", result.stderr)


if __name__ == "__main__":
    unittest.main()
