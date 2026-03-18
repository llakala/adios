{
  pkgs ? import __sources.nixpkgs {},
  __sources ? import ./npins,
}:

pkgs.mkShell {
  packages = [
    pkgs.npins
    pkgs.nix-unit
    pkgs.mdbook
    pkgs.mdbook-cmdrun
  ];
}
