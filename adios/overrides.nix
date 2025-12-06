{ tree, modules }:
let
  inherit (builtins)
    attrNames
    concatMap
    genericClosure
    filter
    concatStringsSep
    ;

  self = {
    mkOverride =
      root: prevEval:
      {
        # Updated options
        options ? { },
        # Whether to allow re-resolving
        resolve ? true,
      }:
      modules.optionsType.check options (
        let
          # TODO: Filter nulled out options
          options' = prevEval.options // options;

          # Names of all modules being updated
          moduleNames = attrNames options;

          # Names of all modules being referenced in the new options, but not present
          # in the old module resolution.
          # If this list is non-empty modules have to be re-resolved.
          newModuleNames = filter (name: !prevEval.resolution ? ${name}) moduleNames;

          # Module dependency resolution
          resolution =
            if newModuleNames != [ ] then
              (
                if resolve then
                  tree.resolveTree root (attrNames options')
                else
                  throw ''
                    Module overriding caused re-resolving, which is disabled.
                    Differing modules: ${concatStringsSep " " newModuleNames}
                  ''
              )
            else
              prevEval.resolution;

          # Resolve which module options/results needs to be invalidated
          diff =
            let
              resolutionNames = attrNames resolution;
            in
            map (result: result.key) (genericClosure {
              startSet = map (key: { inherit key; }) moduleNames;
              operator =
                { key }:
                concatMap (
                  name: if resolution.${name}.inputs ? ${key} then [ { key = name; } ] else [ ]
                ) resolutionNames;
            });

          result = {
            # Overriden eval context
            evalParams = tree.evalModuleTree {
              inherit resolution;
              options = options';
              memoArgs = removeAttrs prevEval.args diff;
              memoResults = removeAttrs prevEval.results diff;
            };

            # Tree context
            root = tree.applyTreeOptions {
              inherit root;
              options = options';
              inherit (result.evalParams) args;
            };

            # Chained override function
            override = self.mkOverride root result.evalParams;
          };
        in
        result
      );
  };
in
self
