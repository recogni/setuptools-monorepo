import importlib.util
import inspect
import os
import subprocess
import sys
from contextlib import contextmanager
from dataclasses import dataclass
from inspect import FullArgSpec
from types import ModuleType
from typing import Any, Dict, Iterable, List, Optional, Sequence

import setuptools

if sys.version_info < (3, 11):
    import tomli as toml
else:
    import tomllib as toml


SCRIPT_MARKER = "monorepo_script.toml"
SCRIPT_ENTRYPOINT = "entrypoint.py"


@dataclass
class Script:
    name: str
    path: str


def _eprint(s: str):
    print("setuptools-monorepo: " + s, file=sys.stderr)


def _run_command(command: List[str], cwd: Optional[str] = None) -> subprocess.CompletedProcess:
    result = subprocess.run(command, capture_output=True, cwd=cwd)

    if result.returncode != 0:
        _eprint("Command {} exited with code {}".format(" ".join(command), result.returncode))
        _eprint(f"stdout: {result.stdout.decode()}")
        _eprint(f"stderr: {result.stderr.decode()}")
        raise RuntimeError()

    return result


def _get_repo_root() -> str:
    result = _run_command(["git", "rev-parse", "--show-toplevel"])
    return result.stdout.decode().strip()


def _find_script_markers(repo: str) -> Iterable[str]:
    result = _run_command(["git", "-C", repo, "ls-files", f"**/{SCRIPT_MARKER}"], repo)
    entries = result.stdout.decode().split("\n")
    return (e for e in entries if e.strip() != "")


def _discover_scripts(repo_root: str) -> Iterable[Script]:
    script_markers = _find_script_markers(repo_root)

    # Ignore files in repo root
    def _is_script(path: str) -> bool:
        entries = path.split(os.path.sep)
        return len(entries) > 1

    def _make_script(path: str) -> Script:
        entries = path.split(os.path.sep)
        # Safe to index to -2 because of condition function above
        name = entries[-2]
        abs_path = repo_root + os.path.sep + os.path.sep.join(entries[:-1])
        return Script(name=name, path=abs_path)

    return (_make_script(marker) for marker in script_markers if _is_script(marker))


def _validate_single_value(value: Any) -> Optional[str]:
    if not isinstance(value, dict):
        return "Value should be a dict"

    value_keys = value.keys()
    valid_keys = ["target", "args"]
    unknown_keys = [key for key in value_keys if key not in valid_keys]

    if unknown_keys:
        return "Unknown params passed: " + " ".join(unknown_keys)

    if not isinstance(value["target"], str):
        return '"target" should be a string'

    if "args" in value and not isinstance(value["args"], dict):
        return '"args" should be a dict'

    return None


def _validate_value(value: Any) -> Optional[str]:
    def _validate_all() -> Optional[str]:
        for entry in value:
            validation_result = _validate_single_value(entry)
            if validation_result is not None:
                return validation_result
        return None

    if isinstance(value, Sequence):
        return _validate_all()

    return _validate_single_value(value)


def _validate_arg(arg_name: str, args: FullArgSpec) -> Optional[str]:
    if arg_name not in args.args:
        return f'"entrypoint" does not accept argument "{arg_name}"'

    return None


@contextmanager
def _add_to_path(additional_path: str):
    old_path = sys.path
    sys.path = sys.path[:]
    sys.path.insert(0, additional_path)

    try:
        yield
    finally:
        sys.path = old_path


def _import_script(script_path: str) -> ModuleType:
    script_dir_path = os.path.dirname(script_path)
    script_parent_path = os.path.abspath(os.path.join(script_dir_path, os.pardir))

    with _add_to_path(script_parent_path):
        spec = importlib.util.spec_from_file_location("module", script_path)
        if spec is None:
            raise RuntimeError(f"Failed to load module spec: {script_path}")

        module = importlib.util.module_from_spec(spec)
        if spec.loader is None:
            raise RuntimeError("No spec loader available")

        spec.loader.exec_module(module)
        return module


def _call_script(dist: setuptools.dist.Distribution, target: str, args: Dict[str, Any]):
    _eprint(f"Looking for monorepo script {target}")

    repo_root = _get_repo_root()
    scripts = _discover_scripts(repo_root)
    target_script = next((s for s in scripts if s.name == target), None)

    if target_script is None:
        _eprint(f"Unable to find script {target}")
        raise RuntimeError()

    imported_script = _import_script(target_script.path + os.path.sep + SCRIPT_ENTRYPOINT)

    if not hasattr(imported_script, "entrypoint"):
        _eprint(f'Unable to find "entrypoint" function in the script "{target_script.name}"')
        raise RuntimeError()

    if not callable(imported_script.entrypoint):
        _eprint(f'"entrypoint" is not a function in the script "{target_script.name}"')
        raise RuntimeError()

    entrypoint_args = inspect.getfullargspec(imported_script.entrypoint)

    if len(entrypoint_args.args) == 0:
        _eprint('function "entrypoint" should accept at least one argument')
        raise RuntimeError()

    if len(entrypoint_args.args) - 1 != len(args):
        _eprint('Number of arguments of "entrypoint" does not match number of provided arguments')
        raise RuntimeError()

    for arg_name, arg_value in args.items():
        maybe_error = _validate_arg(arg_name, entrypoint_args)
        if maybe_error is not None:
            _eprint(maybe_error)
            raise RuntimeError()

    imported_script.entrypoint(dist, **args)


def handle_monorepo_keywords(dist: setuptools.dist.Distribution, attr: str, value: Any):
    validation_result = _validate_value(value)

    if validation_result is not None:
        _eprint(f"invalid argument passed: {validation_result}")
        raise RuntimeError()

    def _get_call_args(call: Dict[str, Any]):
        call_target = call["target"]
        call_args = call["args"] if "args" in call else {}
        return call_target, call_args

    def _make_sequence():
        if isinstance(value, Sequence):
            return value
        else:
            return [value]

    values = _make_sequence()

    for entry in values:
        if not isinstance(entry, Dict):
            _eprint(f"received invalid argument for setuptools-monorepo: not a dict")
            raise RuntimeError()

        target, args = _get_call_args(entry)
        _call_script(dist, target, args)


def handle_monorepo_dist(dist: setuptools.dist.Distribution):
    pyproject_toml = os.path.join(os.getcwd(), "pyproject.toml")
    if not os.path.exists(pyproject_toml):
        return

    def _parse_file():
        with open(pyproject_toml, "rb") as f:
            return toml.load(f)

    project = _parse_file()
    if "tool" not in project:
        return

    if "setuptools_monorepo" not in project["tool"]:
        return

    invocations = project["tool"]["setuptools_monorepo"]
    if not isinstance(invocations, Dict):
        return

    for target, args in invocations.items():
        _call_script(dist, target, args)
