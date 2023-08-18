# Custom Hierarchy Curation Gear

## Table of Contents

[[_TOC_]]

There are a lot of cases where specific logic must be used to curate a given
project.  This hierarchy curation gear is able to take an implementation of
the HierarchyCurator Class (provided as an input file (e.g., curator.py)),
instantiate it and execute it on a project, walking down the hierarchy through
project, subject, session, acquisition, analysis and file containers.

## Description

The Hierarchy curator walks _down_ the hierarchy depth-first by default.
The gear can be launched from any level in the Flywheel Hierarchy and has
access to every container below and including the run container.

For example if the hierarchy curator is run from Subject level, the first
container encountered when walking the hierarchy would be the Subject in which
it was run, then it would walk to each session, then it would walk to each
acquisition under those sessions, and finally each file under those
acquisitions.

For each container encountered when walking the hierarchy, the curator will call
`validate_<container>` to decide whether it should curate that container.  The
`validate_<container>` by default returns True, but can be overriden with custom
logic.

If `validate_<container>` returns True, then `curate_<container>` is called.  In
`curate_<container>`, you have access to the SDK model of that container and the
class instance.  

You can save information from any level into the class instance attribute `data`
itself, and then access that lower down.  For example if you wanted to set file
level information based on subject metadata, you could write a curator like the
following:

```python
from flywheel_gear_toolkit.utils.curator import HierarchyCurator

class Curator(HierarchyCurator):

    def curate_subject(self, sub):
        self.data['sub_label'] = sub.label

    ...
    def curate_file(self, file_):
        if file_.type is 'dicom':
            file_.update_info({'PatientID':self.data['sub_label']})
```

### Gear Inputs

#### Required Inputs

* **curator**: Python script (e.g. curator.py) that implemented the
  `HierarchyCurator` class.  More details at the [Flywheel Gear Toolkit
  docs](https://gear-toolkit.readthedocs.io/en/latest/utils.html#curator).

#### Optional Inputs

* **additional_input_one**: Additional file to be used by the curator.
* **additional_input_two**: Additional file to be used by the curator.
* **additional_input_three**: Additional file to be used by the curator.

> NOTE: See [Input Files](#input-files) for details on how to access inputs.

## HierarchyCurator

### Curator configuration

All configuration for the curator can be accessed via the `config` instance
attribute, which is itself an instance of `CuratorConfig`.  Available config
options are:

* `workers` (integer): Number of multithreaded workers to use (default 1).
* `depth_first` (boolean): Walks depth-first if True and breadth-first if False
  (default True) (See
  [Breadth vs. depth-first traversal](#breadth-first-vs-depth-first-traversal))
* `stop_level` (str): Container level to stop walking at (Default None)
* `callback` (function): Optional callback to decide whether or not to queue a
  given container (default None). (See [Walker Callback](#walker-callback) for
  details)
* `report` (boolean): Whether or not to create a report (default False).
* `format` (BaseLogRecord, see below): Report format (default LogRecord).
* `path` (path): Location to store report (default
  `/flywheel/v0/output/output.csv`).

The curator class must be defined in a python script which is provided to the gear
as an input. This class must be named `Curator` and must inherit from
`flywheel_gear_toolkit.utils.curators.HierarchyCurator` class:

```python
from flywheel_gear_toolkit.utils.curator import HierarchyCurator

class Curator(HierarchyCurator):
    ...
```

### Walker callback The walker callback (configured at `self.config.callback`)

is a function that accepts a container and returns a boolean.  It has the same
signature as `validate_container()`.  When walking the hierarchy, this function
will be called in between selecting the next container and queueing its
children, so you can use this function to dynamically decide if you want to
queue a given container's children.

For example, you can write a custom `to_queue()` callback function to exclude children of
sessions whose label don't match a regex:

```python

def to_queue(container):
    regex = re.compile(r'^trial-\d+$')
    if container.container_type == "session" and regex.match(container.label) is None:
            return False
    return True


class Curator(HierarchyCurator):
    def __init__(self):
        super().__init__(self)
        self.config.callback = to_queue


    def curate_acquisition(acquisition):
        ...
```

In the above example, the curator will walk the hierarchy.  When it reaches a
session, it will first call `self.validate_container()` on that session, which in
turn calls `self.validate_session()` (See [Validation Methods](#validate)).
`self.validate_session()` will only return `True` if the session starts with
`trial-` and has a number (such as `trial-1`).  If `self.validate_session()`
returns False, then the children of that session will not be queued and you
won't curate any acquisitions, analyses, or files under this session.  **NOTE**:
Session attached files would still show up in `curate_file`

### Curate Methods

The Curator Class must define curate methods for each container type
(excluding groups and collections). For each container, the method is
called `curate_<container_type>`. The method takes the container as an input.

For example, for the project container the curation method is defined as:

```python
    def curate_project(self, project):
        ...
```

This pattern is consistent for all containers. For the files container the
method is named `curate_file` and takes `file_` as input (note the underscore).

### Validate Methods

In addition to the curate methods, the implementation can inherit _validate_
methods specific to each container. By default these methods will always
return `True`.

There is a `validate` method for each container level, e.g.
`validate_project()`, `validate_subject()`, etc.  When a container is reached
during the walking process, the `HierarchyCurator` routes it to the correct
method by calling `self.validate_container()`. None, any, or all of these
methods can be extended.

Extending a `validate` method may be useful when curation is a time consuming
process, or you are doing multiple runs of the curation script. For example, you
may tag a file during the curation method and check for that tag later in the
validate method. Below is an example of how one might accomplish that:

```python
from flywheel_gear_toolkit.utils.curator import HierarchyCurator

class Curator(HierarchyCurator):
    ...
    def curate_file(self, file_):
        """Curates a file by setting the field 'file.info.curated' to True"""
        file_.update_info({'curated': True})
    ...
    def validate_file(self, file_):
        """Returns True if file needs curation, False otherwise"""
        return not file_.info.get('curated', False)
```

As shown in the `validate_file` method, the method should return `True` if the
container does need to be curated and `False` if it does not.

### Input files

There are many cases where custom curation may require the use of input files.
This gear provides mechanisms to utilize _optional_ input files.

NOTES:

1. These input files are optional, thus it is necessary to gracefully handle
cases where the input files do not exist.
2. The gear  allows for the use of up to three input files.
3. The inputs must be accessed with the special `self.open_input` context
manager (See below).

The input files can be accessed within the curator class. The path to the input
files are stored within the attribute named `additional_input_one`,
`additional_input_two` and `additional_input_three`.

Below is an example of a Project curation method using the first input file:

```python
def curate_project(self, project):
    if self.additional_input_one:
        with self.open_input(self.additional_input_one, 'r') as input_file:
            for line in input_file:
                project.add_note(line)
```

### Adding extra dependencies

The file-curator gear comes with the following python packages installed:

* lxml
* pandas
* nibabel
* Pillow
* piexif
* pydicom
* pypng
* flywheel-gear-toolkit
* fw-file

**Note**: See package versions in [./pyproject.toml](pyproject.toml)

If you need other dependencies that aren't installed by default, the
gear-toolkit provides an interface to programmatically install dependencies.
You can specify extra packages in the `__init__` method.

```python
from flywheel_gear_toolkit.utils import install_requirements
...
class Curator(HierarchyCurator):
    def __init__(self, **kwargs):
        super().__init__(**kwargs, extra_packages=["tqdm==x.y.z"])
```

NOTE:  These installs only work if you import the dependencies from within a function
top level imports will NOT work.

### Breadth-first vs. depth-first traversal

By default the walker used in HierarchyCuratror uses depth-first traversal, this
can be adjusted by setting the `depth_first` attribute to either `True` or
`False` in your `Curator` class.  

For example if you run the gear from subject `sub-01` and there are two sessions
underneath each with two acquisitions, you might have a tree that looks like:

```bash
sub-01
├── ses-screening
│   ├── acq-anat1
│   │   └── T1w.dicom.zip
│   └── acq-func1
│       └── task1.dicom.zip
└── ses-visit1
   ├── acq-anat1
   │   └── T1w.dicom.zip
   └── acq-func1
       └── task1.dicom.zip
```

If you set your curator to run depth-first:

```python
from flywheel_gear_toolkit.utils import install_requirements
...
class Curator(HierarchyCurator):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.config.depth_first = True
```

Then your traversal order would be as follows:

```bash
sub-01                       1.
├── ses-screening            2. 
│   ├── acq-anat1            3.
│   │   └── T1w.dicom.zip    4. 
│   └── acq-func1            5.
│       └── task1.dicom.zip  6.
└── ses-visit1               7.
   ├── acq-anat1             8.
   │   └── T1w.dicom.zip     9.
   └── acq-func1             10.
       └── task1.dicom.zip   11.
```

Whereas if you want breadth first:

```python
from flywheel_gear_toolkit.utils import install_requirements
...
class Curator(HierarchyCurator):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.config.depth_first = False
```

your traversal order would be:

```bash
sub-01                       1.
├── ses-screening            2. 
│   ├── acq-anat1            4.
│   │   └── T1w.dicom.zip    8. 
│   └── acq-func1            5.
│       └── task1.dicom.zip  9.
└── ses-visit1               3.
   ├── acq-anat1             6.
   │   └── T1w.dicom.zip     10.
   └── acq-func1             7.
       └── task1.dicom.zip   11.
```

## Converting from legacy script to new format

There are a few things you'll need to change to convert from a legacy script to
the new format (if you want the new features):

1. Import: Change the import from `import curator` to
`from flywheel_gear_toolkit.utils.curator import HierarchyCurator`
see [HierarchyCurator](#hierarchycurator) for more details.
2. Subclass: Change the parent class for `Curator` from `Curator` to
`HierarchyCurator`
3. Input files.  See [Optional Inputs](#optional-inputs), and
[Input Files](#input-files) for more details.  
    a. Change all instances of `input_file_<num>` to `additional_input_<num>`  
    b. Change all read's of input files from `with open()` to with `self.open_input()`,
    this is thread safe.  
4. Class config: Change configuration values from passing them to the super
constructor (e.g. `super().__init__(depth_first=True)`) to setting the
`self.config` object, see [Curator Configuration](#curator-configuration)
5. Reporting: Change instantiating report to simply setting `self.config.report`
to `True` and possibly setting the reporting format under `self.config.format`
see [Curator Configuration](#curator-configuration).

Also see the tutorial for a step-by-step walkthrough:
[Converting from legacy](./docs/tutorial_convert_from_legacy.md)

## More information

* [Implementation details](./docs/multiprocessing.md)
* [Contributors Guide](./docs/CONTRIBUTING.md)
