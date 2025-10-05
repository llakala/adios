{ adios, getExe }:
{
  name = "treefmt-deadnix";

  options = {
    package = {
      type = adios.types.derivation;
      # default = pkgs.deadnix;
    };
  };

  impl = options: {
    name = "deadnix";
    treefmt = {
      command = getExe options.package;
      options = [ "--edit" ];
      includes = [ "*.nix" ];
    };
  };
}
