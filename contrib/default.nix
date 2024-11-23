{ self, types }:

{
  name = "adios-contrib";

  options = {
    pkgs.type = types.attrs;
  };

  tests = {
    testType = {
      expr = types.modules.module.verify (
        self
        // {
          # Don't test the shape of tests because of infinite recursion
        }
      );
      expected = null;
    };
  };

  modules = {
    nixos = import ./modules/nixos.nix;
    treefmt = import ./modules/treefmt {
      pkgs' = self.defaults.pkgs;
    };
  };
}
