{ pkgs }:
{
  types,
  lib,
  ...
}:
{
  name = "treefmt-nixfmt";

  options = {
    package = {
      type = types.derivation;
      default = pkgs.nixfmt-rfc-style;
    };
  };

  impl = options: {
    name = "nixfmt";
    treefmt = {
      command = lib.getExe options.package;
      includes = [ "*.nix" ];
    };
  };
}
