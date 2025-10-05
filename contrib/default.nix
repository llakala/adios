{ types }:

{
  name = "adios-contrib";

  options = {
    pkgs.type = types.attrs;
  };

  modules = {
    treefmt = import ./modules/treefmt;
  };
}
