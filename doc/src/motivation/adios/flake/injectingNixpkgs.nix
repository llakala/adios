# flake.nix

# We set the value of the `pkgs` option, so when any other module tries to read
# from it, it'll find the correct value
tree = (adios root).eval {
  options."/nixpkgs" = {
    inherit pkgs;
  };
};
