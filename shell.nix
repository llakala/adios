{
  pkgs ? import __sources.nixpkgs { },
  __sources ? import ./npins,
}:

let
  inherit (pkgs) lib;
  dev = import ./dev { inherit __sources pkgs lib; };

in
pkgs.mkShell {
  packages = [
    pkgs.npins
    pkgs.nix-unit
    dev.treefmt
    pkgs.mdbook
  ];
}
