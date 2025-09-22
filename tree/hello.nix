{ types }:

# Notes on lazyness:
#
# A module is not even evaluated until it's namespace is referenced.
#
# This module loaded under the "hello" attribute is enabled by:
# { "/hello" = { }; }
# but since the module has an enable guard, no package is added yet.
# It in turn loads a other modules for eval:
# - /nixpkgs
# and will call them for side effects.
#
# Enable it by:
# { "/hello" = { enable = true; } }
#
# And if enabled by a previous eval it can be explicitly disabled by:
# { "/hello" = null; }

{
  options = {
    enable = {
      type = types.bool;
      default = false;
    };

    package = {
      type = types.option types.derivation;
      defaultFunc = { inputs, ... }: inputs."/nixpkgs".pkgs.hello;
    };
  };

  # Foreign module inputs
  inputs = {
    # Untyped inputs, assume that the module defining the option is aliging with our expectations.
    # Essentially this is "type inference"
    "/nixpkgs" = null;

    # Or explicitly typed narrower interface
    # "nixpkgs" = {
    #   pkgs = {
    #     type = types.attrs;
    #   };
    # };
  };

  impl =
    {
      options,
      inputs,
    }:
    let
      inherit (inputs."/nixpkgs".pkgs) lib;
    in
    lib.optionalAttrs options.enable {
      packages = [
        options.package
      ];
    };
}
