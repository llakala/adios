{ adios }:

{
  name = "adios-contrib";

  options = {
    pkgs.type = adios.types.attrs;
  };

  modules = {
    treefmt = import ./modules/treefmt { inherit adios; };
  };
}
