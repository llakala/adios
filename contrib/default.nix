{ adios }:

{
  name = "adios-contrib";
  modules = {
    treefmt = import ./modules/treefmt { inherit adios; };
  };
}
