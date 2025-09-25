{
  __sources ? import ./npins,
  pkgs ? import __sources.nixpkgs { },
}:
let
  adios' = import ./. { };
  inherit (adios') adios adios-contrib;
in
(adios.modules.nix-unit {
  modules = [
    adios
    (adios-contrib.apply {
      inherit pkgs;
    })
  ];
}).nixUnitTests
