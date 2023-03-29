# setuptools-monorepo

`setuptools-monorepo` is a plugin for `setuptools` that lets you discover and
run Python scripts when your packages are installed from `git://` URL. This means
that in a monorepo, multiple packages residing in different subfolders and referred
to using `#subdirectory=` attribute can share common setup code.

## Use cases

* resolving dependencies within a monorepo
* automatic generation of package metadata such as version
* installation environment checks (compilers, libraries, native tools etc)

## Usage

### Declaring monorepo scripts

Any directory, except for the root of the repo, will be considered a script
if it contains two files:

```
script_name
├── entrypoint.py
└── monorepo_script.toml
```

`script_name` will be used to refer to the script. `monorepo_script.toml` is empty
for now but is reserved for adding configuration options in the future.

`entrypoint.py` should contain a function declared as follows:

```python
import setuptools

def entrypoint(dist: setuptools.dist.Distribution, arg1: int, arg_n: str):
    pass
```

The first argument of the function is a `Distribution` object that can be modified
by the script. The rest of the args are arbitrary and will be matched by name during
invocation.

When scripts are loaded, parent directory of each script is added to `PYTHONPATH`. This
makes it possible to load code shared between scripts.

### Calling monorepo scripts

#### With `pyproject.toml`

Scripts can be invoked during installation using the following syntax in `pyproject.toml`:

```toml
[tool.setuptools_monorepo.test_script]
arg_1 = [
    "one_of_values_of_arg_1"
]
arg_2 = "some_value"
```

#### With `setup.py`

For `setup.py`, use `monorepo_call` keyword:

```python
from setuptools import setup

if __name__ == '__main__':
    setup(
        setup_requires=['setuptools-monorepo == 0.0.4'],
        monorepo_call={
            'target': 'test_script',
            'args': {
                'arg1': 1,
                'arg2': 'some_string',
            },
        },
    )
```
