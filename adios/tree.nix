{ overrides, modules }:
let
  optionalAttrs = cond: attrs: if cond then attrs else { };

  inherit (builtins)
    attrNames
    listToAttrs
    mapAttrs
    concatMap
    genericClosure
    attrValues
    concatStringsSep
    ;

  self = {
    # Resolve required module dependencies for defined config options
    resolveTree =
      scope: moduleNames:
      listToAttrs (
        map
          (x: {
            name = x.key;
            value = modules.getModule scope x.key;
          })
          (genericClosure {
            # Get startSet from passed config
            startSet = map (key: {
              inherit key;
            }) moduleNames;
            # Discover module dependencies
            operator =
              { key }:
              map (input: {
                key = modules.absModulePath key input.path;
              }) (attrValues (modules.getModule scope key).inputs);
          })
      );

    evalModuleTree =
      {
        # Passed options
        options,
        # Resolved modules attrset
        resolution,
        # Previous eval memoisation
        memoArgs ? { },
        memoResults ? { },
      }:
      rec {
        # Computed options/inputs for each module in resolution
        args =
          mapAttrs (modulePath: module: {
            inputs = mapAttrs (_: input: args.${input.path}.options) module.inputs;
            options = modules.computeOptions args.${modulePath} "while computing ${modulePath} args" module.options (
              options.${modulePath} or { }
            );
          }) resolution
          // memoArgs;

        inherit options resolution;

        # Module call results for each callable module in resolution
        results =
          listToAttrs (
            concatMap (
              modulePath:
              let
                module = resolution.${modulePath};
              in
              if module ? impl then
                [
                  {
                    name = modulePath;
                    value = modules.callFunction module.impl args.${modulePath};
                  }
                ]
              else
                [ ]
            ) (attrNames resolution)
          )
          // memoResults;
      };

    # Apply options to a module tree, returning a new module tree where modules can be called
    # with their inputs already wired up & options partially applied.
    applyTreeOptions =
      {
        # Root module
        root,
        # Passed options
        options,
        # Attrset of computed args from tree eval context
        args,
      }:
      let
        recurse =
          # Path to current module as a list of string
          modulePath':
          # Current module
          module:
          let
            # Create submodule path string
            modulePath = "/" + concatStringsSep "/" modulePath';

            # Module arguments
            args' =
              # Take args from resolved context if it's available there.
              args.${modulePath} or
              # fall back to computing
              {
                inputs = mapAttrs (
                  _: input: (modules.getModule tree' (modules.absModulePath modulePath input.path)).args.options
                ) module.inputs;
                options = modules.computeOptions args' "while computing ${modulePath} args" module.options (
                  options.${modulePath} or { }
                );
              };
          in
          module
          // {
            args = args';
            # Recurse into child modules
            modules = mapAttrs (moduleName: recurse (modulePath' ++ [ moduleName ])) module.modules;
          }
          // optionalAttrs (module ? impl) {
            # Wrap module call with computed args
            __functor =
              let
                passedOptions = options.${modulePath} or { };
              in
              moduleSelf: options:
              let
                # Concat passed options with options passed to tree eval
                options' = modules.mergeOptionsUnchecked moduleSelf.options passedOptions options;
                # Re-compute args fixpoint with passed args
                args = {
                  inherit (moduleSelf.args) inputs;
                  options = modules.computeOptions args "while calling ${modulePath}" module.options options';
                };
              in
              # Call implementation
              moduleSelf.impl args;
          };

        tree' = recurse [ ] root;
      in
      tree';

    # Load a module tree recursively from root module
    loadTree =
      root:
      let
        root' = modules.loadModule root;
      in
      {
        root = root';

        eval =
          {
            options ? { },
          }:
          modules.optionsType.check options (
            let
              result = {
                # Eval context
                evalParams =
                  let
                    resolution = self.resolveTree root' (attrNames options);
                  in
                  self.evalModuleTree { inherit resolution options; };

                # Tree context
                root = self.applyTreeOptions {
                  root = root';
                  inherit options;
                  inherit (result.evalParams) args;
                };

                # Chained override function
                override = overrides.mkOverride root' result.evalParams;
              };
            in
            result
          );
      };

  };
in
self
