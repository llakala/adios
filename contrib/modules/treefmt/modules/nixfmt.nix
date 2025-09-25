{ pkgs }:
{
  types,
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
      command = pkgs.lib.getExe options.package;
      includes = [ "*.nix" ];
    };
  };
}
