# modules/hello.nix
{ adios, pkgs }:
{
  options = {
    package = {
      type = adios.types.derivation;
      default = pkgs.hello;
    };
  };

  # A module's "impl" can be called with the values of the options
  # The `options` parameter here is like `config` in the nixos module system -
  # but only for the locally defined options
  impl = { options }: options.package;
}
