{
  lib,
  pkgs,
  config,
  ...
}:

let
  # `config` is a special variable passed to all modules, that lets us read from
  # what the user set our options to
  # We create a QOL variable so we can read from the state of OUR options, since
  # that's all we'll be wanting to inspect
  cfg = config.programs.hello;
in
{
  # Anything under the `options` attribute will create some typechecked API for
  # the user
  options.programs.hello = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable installing `hello` onto your system";
    };
    package = {
      type = lib.types.package;
      default = pkgs.hello;
      description = "The package to be installed";
    };
  };

  # Anything under the toplevel `config` attribute in a module will mutate the
  # state of other modules. Here, `environment.systemPackages` is an
  # already-existing module, that has a specific meaning to NixOS (it controls
  # the package installed on your system).
  #
  # Note that this config _attribute_ has a separate meaning from the config
  # _variable_ - the variable is for reading from the state of config, whicle
  # the attribute is for setting config.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
