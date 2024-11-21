{
  nixImpl ? "nix",
  pkgs ? import __sources.nixpkgs { },
  __sources ? import ./npins,
}:

let
  sources = __sources;

  inherit (pkgs) lib;

  testImpls = {
    nix = pkgs.nix-unit;

    lix =
      let
        lix = pkgs.callPackage "${sources.lix}/package.nix" {
          stdenv = pkgs.clangStdenv;
        };

        lix-unit =
          (pkgs.nix-unit.override {
            # Hacky overriding :)
            nixVersions = lib.mapAttrs (_n: _v: lix) pkgs.nixVersions;
            # nix = pkgs.lixVersions.latest;
          }).overrideAttrs
            (_old: {
              pname = "lix-unit";
              name = "lix-unit-${lix.version}";
              inherit (lix) version;
              src = sources.lix-unit;
            });
      in
      lix-unit;
  };

  dev = import ./dev { inherit __sources pkgs lib; };

in
pkgs.mkShell {
  packages = [
    pkgs.npins
    testImpls.${nixImpl}
    dev.treefmt
    pkgs.mdbook
  ];
}
