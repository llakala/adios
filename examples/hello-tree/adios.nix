{ adios }:
{
  modules = {
    hello = import ./modules/hello.nix { inherit adios; };
    nixpkgs = import ./modules/nixpkgs.nix { inherit adios; };
  };
}
