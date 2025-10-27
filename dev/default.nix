{
  __sources ? import ../npins,
  pkgs ? import __sources.nixpkgs { },
  adios' ? import ../.,
  adios-contrib ? adios'.adios-contrib,
}:

let
  inherit (pkgs) callPackage;
in
{
  doc = callPackage ../doc { };
}
