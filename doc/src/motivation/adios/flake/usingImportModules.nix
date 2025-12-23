# flake.nix

root = {
  modules = adios.lib.importModules ./modules;
};
