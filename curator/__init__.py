import logging

from flywheel_gear_toolkit.utils.curator import HierarchyCurator as Curator

setattr(Curator, "legacy", True)

log = logging.getLogger()
log.warning(
    "Importing `curator` is being deprecated.  Please use `from flywheel_gear_toolkit.utils import curator` and extend `curator.HierarchyCurator`"
)
