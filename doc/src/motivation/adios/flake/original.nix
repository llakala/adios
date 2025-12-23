# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    adios.url = "github:adisbladis/adios";
  };

  outputs =
    inputs:
    let
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      adios = (import inputs.adios).adios;

      module = import ./modules/hello.nix { inherit adios pkgs; };

      # The purpose of `.eval` will be explained soon! For now, call it with
      # nothing.
      evaluatedModule = (adios module).eval {};

      # The module now acts as a function, which we can call with our desired
      # values for the options
      helloPackage = evaluatedModule.root {
        package = pkgs.hello.overrideAttrs {
          doCheck = false;
        };
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.git
          helloPackage
        ];
      };
    };
}
