{
  __sources ? import ../npins,
  pkgs ? import __sources.nixpkgs { },
}:

let
  inherit (pkgs) callPackage;
in
{
  doc = callPackage ./package.nix { };
}
