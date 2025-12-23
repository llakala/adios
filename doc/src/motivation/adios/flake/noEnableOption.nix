# flake.nix

helloPackage = evaluatedModule.root {
  package = pkgs.hello.overrideAttrs {
    doCheck = false;
  };
};
