# flake.nix

root = {
  modules = {
    hello = import ./modules/hello.nix { inherit adios; };
    nixpkgs = import ./modules/nixpkgs.nix { inherit adios; };
  };
};

# The purpose of `.eval` will be explained soon! For now, call it with nothing.
tree = (adios module).eval {};

# The module now acts as a function, which we can call with our desired values
# for the options
helloPackage = tree.root.modules.hello {
  package = pkgs.hello.overrideAttrs {
    doCheck = false;
  };
};
