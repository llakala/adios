{ pkgs }:
{
  types,
  ...
}:
{
  name = "treefmt-deadnix";

  options = {
    package = {
      type = types.derivation;
      default = pkgs.deadnix;
    };
  };

  impl = options: {
    name = "deadnix";
    treefmt = {
      command = pkgs.lib.getExe options.package;
      options = [ "--edit" ];
      includes = [ "*.nix" ];
    };
  };
}
