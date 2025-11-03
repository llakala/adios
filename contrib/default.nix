{ adios }:

{
  name = "adios-contrib";

  modules = {
    treefmt = import ./modules/treefmt { inherit adios; };
    write-files = import ./modules/write-files { inherit adios; };
    nixpkgs = import ./modules/nixpkgs { inherit adios; };
  };
}
