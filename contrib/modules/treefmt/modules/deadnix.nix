{ getExe }:
{
  types,
  ...
}:
{
  name = "treefmt-deadnix";

  options = {
    package = {
      type = types.derivation;
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
