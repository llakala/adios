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

      root = {
        modules = adios.lib.importModules ./modules;
      };

      # We set the value of the `pkgs` option, so when any other module tries to
      # read from it, it'll find the correct value
      tree = (adios root).eval {
        options."/nixpkgs" = {
          inherit pkgs;
        };
      };

      # The module now acts as a function, which we can call with our desired
      # values for the options
      helloPackage = tree.root.modules.hello {
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
