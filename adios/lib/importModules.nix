{ adios }:

let
  inherit (builtins)
    attrNames
    pathExists
    readDir
    concatMap
    listToAttrs
    match
    head
    ;

  matchNixFile = match "(.+)\.nix$";
in
rootPath:
let
  files = readDir rootPath;
in
listToAttrs (
  concatMap (
    name:
    if files.${name} == "directory" then
      if pathExists (rootPath + "/${name}/default.nix") then
        [
          {
            inherit name;
            value = import (rootPath + "/${name}") adios;
          }
        ]
      else
        [ ]
    else
      let
        m = matchNixFile name;
        moduleName = head m;
      in
      if m != null && name != "default.nix" then
        [
          {
            name =
              if files ? ${moduleName} then
                throw ''
                  Module ${moduleName} was provided by both:
                  - ${rootPath}/${moduleName}/default.nix
                  - ${name}

                  This is ambigious. Restructure your code to not have ambigious module names.
                ''
              else
                moduleName;
            value = import (rootPath + "/${name}") adios;
          }
        ]
      else
        [ ]
  ) (attrNames files)
)
