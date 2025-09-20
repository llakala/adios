{ adios }:

let
  inherit (builtins) mapAttrs foldl' attrValues;
  inherit (adios) types;

  testModules = mapAttrs (_name: adios) {

    enableOption = _: {
      name = "enableOption";
      options = {
        enable = {
          type = types.bool;
          default = true;
        };
      };
      impl = _: throw "Not callable";
    };

    unsetOption = _: {
      name = "unsetOption";
      options = {
        unset = {
          type = types.bool;
        };
      };
      impl = _: throw "Not callable";
    };

    subOptions = _: {
      name = "subOptions";
      options = {
        foo = {
          options = {
            enable = {
              type = types.bool;
              default = true;
            };
          };
        };
      };
      impl = _: throw "Not callable";
    };

    withSubmodule = _: {
      name = "withSubmodule";
      modules = {
        myModule = _: {
          name = "mymodule";
        };
      };
    };

    withDependentOptions = _: {
      name = "withDependentOption";
      options = {
        a = {
          type = types.string;
          default = "a";
        };
        b = {
          type = types.string;
          defaultFunc = args: "${args.a}-computed";
        };
      };
      impl = args: {
        inherit args;
      };
    };
  };

in
{
  # Check that the exported main module matches our type
  moduleTypes = {
    testAdios = {
      expr = types.modules.module.verify adios;
      expected = null;
    };

    testTestModules = {
      expr = foldl' (
        acc: v:
        let
          err = types.modules.module.verify v;
        in
        if acc != null then
          acc
        else if err != null then
          err
        else
          null
      ) null (attrValues testModules);
      expected = null;
    };
  };

  apply = {
    # Test that applying a new value updates it
    testUnsetOption = {
      expr =
        (testModules.unsetOption.apply {
          unset = false;
        }).defaults;
      expected = {
        unset = false;
      };
    };

    # Test that wrong type throws
    testWrongtype = {
      expr =
        (testModules.unsetOption.apply {
          unset = "nope";
        }).defaults;
      expecedError.type = "ThrownError";
      expectedError.msg = "type error Expected type 'bool'";
    };
  };

  modules = {
    testSubModuleSmokeTest = {
      expr = testModules.withSubmodule.name;
      expected = "withSubmodule";
    };
  };

  # Check that transformation of options to defaults works correctly
  defaults = {
    # Test that a basic option works
    testEnableOption = {
      expr = testModules.enableOption.defaults;
      expected = {
        enable = true;
      };
    };

    # Check that sub options work
    testSubOptions = {
      expr = testModules.subOptions.defaults;
      expected = {
        foo = {
          enable = true;
        };
      };
    };

    # Check that an unset option throws
    testUnsetOption = {
      expr = testModules.unsetOption.defaults;
      expectedError.type = "ThrownError";
      expectedError.msg = "option 'unset' is unset";
    };
  };

  # Check that transformation of options to type works correctly
  type = {
    testEnableOption = {
      expr = testModules.enableOption.type.verify {
        enable = true;
      };
      expected = null;
    };

    testSubOptions = {
      expr = testModules.subOptions.type.verify {
        foo = {
          enable = true;
        };
      };
      expected = null;
    };
  };

  # Check that dependent options work
  dependentOptions = {
    testDependentDefault = {
      expr = (testModules.withDependentOptions { }).args;
      expected = {
        a = "a";
        b = "a-computed";
      };
    };

    testDependentArg = {
      expr = (testModules.withDependentOptions { a = "b"; }).args;
      expected = {
        a = "b";
        b = "b-computed";
      };
    };
  };
}
