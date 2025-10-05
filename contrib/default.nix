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
    treefmt = import ./modules/treefmt;
  };
}
