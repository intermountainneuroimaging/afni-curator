"""Flywheel gear context parser."""


def parse_config(gear_context):
    """Parse gear config.

    Args:
        gear_context (flywheel_gear_toolkit.GearToolkitContext): context

    Returns:
        (tuple): tuple containing
            - parent container
            - curator path
            - dictionary of input files
            - optional requirements file
    """
    analysis_id = gear_context.destination["id"]
    analysis = gear_context.client.get_analysis(analysis_id)

    get_parent_fn = getattr(gear_context.client, f"get_{analysis.parent.type}")
    parent = get_parent_fn(analysis.parent.id)

    curator_path = gear_context.get_input_path("curator")

    input_file_one = gear_context.get_input_path("additional-input-one")
    input_file_two = gear_context.get_input_path("additional-input-two")
    input_file_three = gear_context.get_input_path("additional-input-three")
    input_files = {
        "additional_input_one": input_file_one,
        "additional_input_two": input_file_two,
        "additional_input_three": input_file_three,
    }
    return parent, curator_path, input_files
