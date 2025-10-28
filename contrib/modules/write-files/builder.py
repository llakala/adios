#!/usr/bin/env python3
# pyright: reportAny=false
from typing import TypedDict, NotRequired
from pathlib import Path
import json
import os


class SMFHFile(TypedDict):
    # Note: Making liberal use of NotRequired
    target: NotRequired[str]
    type: NotRequired[str]
    source: NotRequired[str]
    uid: NotRequired[int]
    gid: NotRequired[int]
    permissions: NotRequired[str]


class SMFHManifest(TypedDict):
    files: list[SMFHFile]
    clobber_by_default: bool
    version: int


def main():
    # Read input manifest
    with open(".attrs.json") as fp:
        attrs = json.load(fp)
    manifest = attrs["manifest"]

    # Output smfh manifest
    files: list[SMFHFile] = []

    out = Path(os.environ["out"])
    out.mkdir()

    # Write out inlined (text) files to this directory
    file_store = out.joinpath("files")
    file_store.mkdir()

    for filename, fmeta in manifest["files"].items():
        permissions = fmeta.get("permissions")

        fout: SMFHFile = {
            "target": "/".join((manifest["output"], filename)),
            "permissions": permissions,
            "uid": fmeta.get("uid"),
            "gid": fmeta.get("gid"),
        }

        # Regular files
        has_source = "source" in fmeta
        has_text = "text" in fmeta
        if has_source or has_text:
            fout["type"] = fmeta.get("method", "symlink")

            # Files from a given source
            if has_source:
                # Recursive files
                if fmeta.get("recursive", False):
                    r_source = fmeta["source"]
                    for r_root, _, r_files in os.walk(r_source):
                        for r_file in r_files:
                            file_rel = r_root.removeprefix(r_source)
                            if file_rel:
                                file_rel = "/".join((file_rel, r_file)).removeprefix("/")
                            else:
                                file_rel = r_file.removeprefix("/")
                            files.append(
                                {
                                    **fout,
                                    "source": "/".join((r_source, file_rel)),
                                    "target": "/".join((fout["target"], file_rel)),
                                }
                            )

                # Regular files
                else:
                    files.append({**fout, "source": fmeta["source"]})

            # Inline text based files
            elif has_text:
                file_out = file_store.joinpath(filename)
                file_out.parent.mkdir(exist_ok=True, parents=True)
                with file_out.open("w") as fp:
                    fp.write(fmeta["text"])
                    if permissions:
                        os.fchmod(fp.fileno(), int(permissions, base=8))
                fout["source"] = str(file_out)
                files.append({**fout, "source": str(file_out)})

        # Directory
        else:
            files.append({**fout, "type": "directory"})

    with out.joinpath("manifest.json").open("w") as fp:
        smfh: SMFHManifest = {
            "files": files,
            "clobber_by_default": False,
            "version": 1,
        }
        json.dump(smfh, fp)


if __name__ == "__main__":
    main()
