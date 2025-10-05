{ adios, getExe }:
{
  name = "treefmt-nixfmt";

  options = {
    package = {
      type = adios.types.derivation;
      # default = pkgs.nixfmt-rfc-style;
    };
  };

  impl = options: {
    name = "nixfmt";
    treefmt = {
      command = getExe options.package;
      includes = [ "*.nix" ];
    };
  };
}
