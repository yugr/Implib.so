"""Verify release archive contents and GitHub release metadata."""

from pathlib import Path
import email
import json
import os
import tarfile
import unittest
import zipfile


class DistributionTests(unittest.TestCase):
    """Check the actual files destined for PyPI."""

    def setUp(self):
        """Use the unmodified upstream license as the source of truth."""
        root = Path(__file__).resolve().parent.parent
        license_path = root / "LICENSE.txt"
        self.assertTrue(license_path.is_file(), "The upstream LICENSE.txt is missing")
        self.expected_license = license_path.read_bytes()
        self.assertTrue(self.expected_license.strip(), "LICENSE.txt must not be empty")
        self.dist = root / "dist"

    def test_wheel_license(self):
        """Require the complete MIT notice in the installed wheel."""
        wheels = list(self.dist.glob("*.whl"))
        self.assertEqual(len(wheels), 1, "Build one wheel in a clean dist directory")
        with zipfile.ZipFile(wheels[0]) as archive:
            licenses = [
                name for name in archive.namelist()
                if name.endswith("/LICENSE.txt")
            ]
            self.assertEqual(len(licenses), 1, "The wheel must contain one LICENSE.txt")
            self.assertEqual(archive.read(licenses[0]), self.expected_license)

    def test_sdist_license(self):
        """Require the complete MIT notice in the source distribution."""
        sources = list(self.dist.glob("*.tar.gz"))
        self.assertEqual(len(sources), 1, "Build one sdist in a clean dist directory")
        with tarfile.open(sources[0]) as archive:
            licenses = [
                member for member in archive.getmembers()
                if member.name.endswith("/LICENSE.txt")
            ]
            self.assertEqual(len(licenses), 1, "The sdist must contain one LICENSE.txt")
            license_file = archive.extractfile(licenses[0])
            if license_file is None:
                self.fail("The sdist LICENSE.txt is not a readable file")
            with license_file:
                self.assertEqual(license_file.read(), self.expected_license)

    def wheel_metadata(self):
        """Read the single wheel's package metadata."""
        wheels = list(self.dist.glob("*.whl"))
        self.assertEqual(len(wheels), 1, "Build one wheel in a clean dist directory")
        with zipfile.ZipFile(wheels[0]) as archive:
            records = [
                name for name in archive.namelist()
                if name.endswith(".dist-info/METADATA")
            ]
            self.assertEqual(len(records), 1, "The wheel must contain one METADATA file")
            return email.message_from_bytes(archive.read(records[0]))

    def test_wheel_license_metadata(self):
        """Require SPDX metadata or a standards-compliant legacy declaration."""
        metadata = self.wheel_metadata()
        version = metadata["Metadata-Version"]
        if version is None:
            self.fail("The wheel must declare its metadata version")
        if tuple(map(int, version.split("."))) >= (2, 4):
            self.assertEqual(metadata["License-Expression"], "MIT")
        else:
            self.assertEqual(metadata["License"], "MIT")
            self.assertIsNone(metadata["License-Expression"])
            self.assertIsNone(metadata["License-File"])

    def test_release_version(self):
        """Require a stable release tag to match the built package version."""
        if os.environ.get("GITHUB_EVENT_NAME") != "release":
            self.skipTest("Release version checks only apply to GitHub releases")
        event_path = Path(os.environ["GITHUB_EVENT_PATH"])
        release = json.loads(event_path.read_text(encoding="utf-8"))["release"]
        if release["prerelease"]:
            self.skipTest("GitHub prereleases are not published to PyPI")
        tag = release["tag_name"]
        version = tag[1:] if tag.startswith("v") else tag
        self.assertEqual(
            self.wheel_metadata()["Version"],
            version,
            "Release tag must match the built version; update project.version "
            "in pyproject.toml before creating a release",
        )


if __name__ == "__main__":
    unittest.main()
