# modules/hello.nix
{ adios }:
{
  inputs = {
    # This "path" corresponds to attribute selection under the root module.
    # `/foo/bar` would look for a module under root named `foo`, that itself
    # provides a pointer to a module named `bar`.
    # Note that this isn't based on the filesystem, and instead the names of
    # attributes under `modules`.
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    package = {
      type = adios.types.derivation;
      # A `default` can only be a constant that's known before "full evaluation".
      # To read from an input module, we need to use a `defaultFunc`, which will
      # only be called when we actually use the module
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.git;
    };
  };

  # A module's "impl" can be called with the values of the options
  # The `options` parameter here is like `config` in the nixos module system -
  # but only for the locally defined options
  impl = { options }: options.package;
}
