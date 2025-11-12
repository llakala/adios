#!/usr/bin/env python3
from typing import TypedDict, NotRequired
from pathlib import Path
import subprocess
import shlex
import json
import os


class PrefixedEnv(TypedDict):
    name: str
    value: str
    sep: str


class Options(TypedDict):
    name: str
    paths: NotRequired[list[str]]
    argv0: NotRequired[str]
    inheritArgv0: NotRequired[bool]
    resolveArgv0: NotRequired[bool]
    appendFlas: NotRequired[list[str]]
    chdir: NotRequired[str]
    env: NotRequired[dict[str, str]]
    setDefaultEnv: NotRequired[dict[str, str]]
    unsetEnv: NotRequired[list[str]]
    prefixEnv: NotRequired[PrefixedEnv]
    suffixEnv: NotRequired[PrefixedEnv]


def main():
    out = Path(os.environ["out"])
    bin = out.joinpath("bin")
    out.mkdir()

    with open(".attrs.json") as fp:
        attrs = json.load(fp)
    options: Options = attrs["options"]

    mk_wrapper_args: list[str] = []

    try:
        mk_wrapper_args.extend(["--argv0", options["argv0"]])
    except KeyError:
        pass

    if options.get("inheritArgv0", False):
        mk_wrapper_args.append("--inherit-argv0")

    if options.get("resolveArgv0", False):
        mk_wrapper_args.append("--resolve-argv0")

    try:
        mk_wrapper_args.extend(options["addFlags"])
    except KeyError:
        pass

    try:
        mk_wrapper_args.extend(options["appendFlags"])
    except KeyError:
        pass

    try:
        mk_wrapper_args.extend("--chdir", options["chdir"])
    except KeyError:
        pass

    for name, value in options.get("env", { }).items():
        mk_wrapper_args.extend(["--set", name, value])

    for name, value in options.get("setDefaultEnv", { }).items():
        mk_wrapper_args.extend(["--set-default", name, value])

    for name in options.get("unsetEnv", []):
        mk_wrapper_args.extend(["--unset", name])

    if "prefixEnv" in options:
        pass

    if "suffixEnv" in options:
        pass

    for input_path in options.get("paths", []):
        path = Path(input_path)
        _ = subprocess.check_output(["lndir", str(path), str(out)])
        for bin_file in path.joinpath("bin").iterdir():
                out_bin = bin.joinpath(bin_file.name)
                print(shlex.join([
                    "wrapProgram",
                    str(out_bin),
                ] + mk_wrapper_args))


if __name__ == "__main__":
    main()
