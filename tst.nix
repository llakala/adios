let
  adios' = import ./. { };
  inherit (adios') adios;

  # Import tree evaluation bits
  treeval = import ./tree.nix { inherit adios; };

  # The root module of this tree
  # TODO: Create an ergonomic "mount" function based on module.override
  root = adios (
    { }:
    {
      modules = adios.lib.loadDir {
        dir = ./tree;
      };
    }
  );

  # Call a tree of modules with config
  evalResult = treeval {
    inherit root;
    options = {
      "/hello".enable = true;
    };
  };

in
{
  inherit evalResult;

  # Re-evaluate system with new config parameters
  evalResult2 = evalResult.override {
    # Updated options
    options = {
      "hello".enable = false;
    };
  };
}
