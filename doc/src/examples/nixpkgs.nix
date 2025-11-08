{ adios }:
let
  inherit (adios) types;
in
{
  options = {
    pkgs = {
      type = types.attrs;
      default = import <nixpkgs> { };
    };
  };
}
