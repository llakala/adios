let
  types = import ./types.nix {
    korora = import ../types/types.nix;
  };
  modules = import ./modules.nix { inherit types; };
  tree = import ./tree.nix { inherit overrides modules; };
  overrides = import ./overrides.nix { inherit tree modules; };

  # Helper functions for users, accessed through `adios.lib`
  lib = {
    importModules = import ./lib/importModules.nix { inherit adios; };
  };

  adios =
    (modules.loadModule {
      name = "adios";
      inherit types lib;
    })
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: tree.loadTree;
    };

in
adios
