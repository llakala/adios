let
  inherit (builtins)
    readDir
    listToAttrs
    concatMap
    match
    pathExists
    elemAt
    attrNames
    ;
in
{
  # Load modules from a directory
  loadDir =
    { dir }:
    let
      contents = readDir dir;
    in
    listToAttrs (
      concatMap (
        name:
        let
          type = contents.${name};
          m = match "(.*)\\.nix" name;
        in
        if type == "directory" && pathExists (dir + "/${name}/adios.nix") then
          [
            {
              inherit name;
              value = import (dir + "/${name}/adios.nix");
            }
          ]
        else if type == "regular" && m != null then
          [
            {
              name = elemAt m 0;
              value = import (dir + "/${name}");
            }
          ]
        else
          [ ]
      ) (attrNames contents)
    );
}
