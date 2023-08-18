"""Utilities for running the curator."""

import logging
import typing as t

import flywheel
from flywheel_gear_toolkit.utils import curator as c
from flywheel_gear_toolkit.utils import datatypes, reporters, walker

log = logging.getLogger(__name__)


def container_to_pickleable_dict(container: datatypes.Container) -> t.Dict[str, str]:
    """Take a flywheel container and transform into
    a simple dictionary that can be pickled for
    multiprocessing, excluding flywheel SDK.
    """
    val = {
        "id": container.id,
        "container_type": container.container_type,
    }
    if container.container_type == "file":
        if hasattr(container, "file_id"):
            val["id"] = container.file_id
        val["parent_type"] = container.parent_ref.get("type")
        val["parent_id"] = container.parent_ref.get("id")
    return val


def container_from_pickleable_dict(
    val: t.Dict, local_curator: c.HierarchyCurator
) -> datatypes.Container:
    """Take the simple pickleable dict entry and
    return the flywheel container.
    """
    get_container_fn = getattr(
        local_curator.context.client, f"get_{val['container_type']}"
    )
    container = get_container_fn(val["id"])
    return container


def handle_work(
    children: t.List[t.Dict[str, str]],
    local_curator: c.HierarchyCurator,
    handle: t.Callable[[c.HierarchyCurator, t.List[datatypes.Container]], None],
):
    """Convert list of dicts into list of containers,
    perform a callback on this list of containers.
    """
    containers = []
    for child in children:
        try:
            container = container_from_pickleable_dict(child, local_curator)
        except flywheel.rest.ApiException as e:
            log.error("Could not get container, skipping curation", exc_info=True)
        else:
            containers.append(container)
    handle(local_curator, containers)


def make_walker(container: datatypes.Container, curator: c.HierarchyCurator):
    """Generate a walker from a container and curator."""
    w = walker.Walker(
        container,
        depth_first=curator.config.depth_first,
        reload=curator.config.reload,
        stop_level=curator.config.stop_level,
    )
    return w


def reload_file_parent(
    container: datatypes.Container,
    local_curator: c.HierarchyCurator,
):
    if getattr(container, "container_type", "") == "file":
        if getattr(container, "parent", None):
            return container
        get_parent_fn = getattr(
            local_curator.context.client, f"get_{container.parent_ref.type}"
        )
        container._parent = get_parent_fn(container.parent_ref.id)
    return container
