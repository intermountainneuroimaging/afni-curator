#!/usr/bin/python3
"""Hierarchy Curator gear entrypoint."""
import sys, os

from flywheel_gear_toolkit import GearToolkitContext

from fw_gear_afni_curator import curate, parser

os.chdir('/flywheel/v0')
if __name__ == "__main__":  # pragma: no cover
    with GearToolkitContext() as gear_context:
        gear_context.init_logging()
        parent, curator_path, input_files = parser.parse_config(gear_context)

        r_code = curate.main(
            gear_context,
            parent,
            curator_path,
            **input_files,
        )
        sys.exit(r_code)
