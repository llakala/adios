{
  pkgs ? import __sources.nixpkgs { },
  __sources ? import ./npins,
}:

let
  dev = import ./dev { inherit __sources pkgs; };

in
pkgs.mkShell {
  packages = [
    pkgs.npins
    pkgs.nix-unit
    dev.treefmt
    pkgs.mdbook
  ];
}
