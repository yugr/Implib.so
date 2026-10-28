"""Command-line entry point for the bundled Implib.so generator."""

import os.path
import runpy


def main():
    """Run the original script alongside its architecture templates."""
    runpy.run_path(
        os.path.join(os.path.dirname(__file__), "implib-gen.py"),
        run_name="__main__",
    )
