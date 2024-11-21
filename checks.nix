{
  __sources ? import ./npins,
  pkgs ? import __sources.nixpkgs { },
  lib ? pkgs.lib,
}:
let
  adios' = import ./. { inherit lib; };
  inherit (adios') adios adios-contrib;
in
(adios.modules.checks {
  modules = [
    adios
    (adios-contrib.apply {
      inherit pkgs;
    })
  ];
}).checks
