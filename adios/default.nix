let
  inherit (builtins) attrValues concatLists concatStringsSep;

  types = import ./types.nix {
    korora = import ../korora;
  };

  # Helper functions for users, accessed through `adios.lib`
  lib = {
    importModules = import ./lib/importModules.nix { inherit adios; };
    merge = {
      lists.concat = { mutators }: concatLists (attrValues mutators);
      strings.concatLines = { mutators }: concatStringsSep "\n" (attrValues mutators);
      attrs.flat = import ./lib/merge-attrs-flat.nix;
      attrs.recursively = import ./lib/merge-attrs-recursively.nix {
        inherit (import ../korora/lib.nix) toPretty;
      };
      general.withPrio = import ./lib/withPrio.nix;
    };
  };

  loadTree = import ./loadTree.nix types;

  adios = {
    inherit types lib;
    __functor =
      _: rootDef:
      {
        options ? { },
      }:
      let
        # Allow viewing the final result while using the tree for fetching
        # modules relative to root
        tree = loadTree tree options rootDef;
      in
      tree;
  };

in
adios
