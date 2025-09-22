{ adios }:
let
  inherit (adios) types;
  inherit (builtins)
    genericClosure
    attrNames
    filter
    isString
    split
    foldl'
    listToAttrs
    concatMap
    mapAttrs
    head
    tail
    removeAttrs
    ;

  splitString = sep: s: filter isString (split sep s);

  getModule =
    # TODO: Relative module lookups allowing
    # /baz
    # ./foo
    # ../bar
    # ..
    scope: name:
    assert name != "";
    let
      tokens = splitString "/" name;
    in
    # Assert that module input begins with a /
    assert head tokens == "";
    foldl' (acc: tok: acc.modules.${tok}) scope (tail tokens);

  # Resolve required module dependencies for defined config options
  resolveModules =
    scope: moduleNames:
    let
      resolution = genericClosure {
        # Get startSet from passed config
        startSet = map (key: { inherit key; }) moduleNames;
        # Discover module dependencies
        operator =
          { key }:
          let
            module = getModule scope key;
            inputs = module.inputs or { };
          in
          map (key: { inherit key; }) (attrNames inputs);
      };

      self = {
        # List of resolved dependencies for set config options
        names = map (x: x.key) resolution;

        # Map dot delimited names to their module
        modules = listToAttrs (
          map (name: {
            inherit name;
            value = getModule scope name;
          }) self.names
        );
      };
    in
    self;

  evalModules =
    {
      options,
      resolution,
      cache ? {
        args = { };
        results = { };
      },
    }:
    let
      inherit (resolution) modules;
    in
    rec {
      # Compute options/inputs for each module
      args =
        let
          inputs = mapAttrs (name: _: args.${name}.options) modules;
        in
        mapAttrs (
          name: module:
          module.args {
            options = options.${name} or { };
            inherit inputs;
          }
        ) resolution.modules
        // cache.args;

      # Call results per module
      results =
        listToAttrs (
          concatMap (
            name:
            let
              module = modules.${name};
            in
            if !module ? __functor then
              [ ]
            else
              [
                {
                  inherit name;
                  # Call module
                  value = module (
                    args.${name}
                    // {
                      __checked = true;
                    }
                  );
                }
              ]
          ) resolution.names
        )
        // cache.results;

    };

  # A coarse grained options type for input validation
  optionsType = types.attrsOf types.attrs;

  mkOverride =
    root: prevEval:
    {
      # Updated options
      options,
      # Whether to allow re-resolving in a config update
      resolve ? false,
    }:
    optionsType.check options (
      let
        # Names of all modules being updated
        moduleNames = attrNames options;

        # Names of all modules being referenced in the new options, but not present
        # in the old module resolution.
        # If this list is non-empty modules have to be re-resolved.
        newModuleNames = filter (name: !prevEval.resolution.modules ? ${name}) moduleNames;

        # Module dependency resolution
        resolution =
          if newModuleNames != [ ] then
            (
              if resolve then
                let
                  # TODO: Filter nulled out options
                  newOptions = prevEval.options // options;
                in
                resolveModules root (attrNames newOptions)
              else
                throw ''
                  Module overriding caused re-resolving, which is disabled.
                  Offending modules: ${builtins.concatStringsSep " " newModuleNames}
                ''
            )
          else
            prevEval.resolution;
        inherit (resolution) modules;

        # Resolve which modules needs to be invalidated
        # TODO: Make diff resolution cacheable
        diff = map (result: result.key) (genericClosure {
          startSet = map (key: { inherit key; }) moduleNames;
          operator =
            { key }:
            concatMap (
              name: if modules.${name}.inputs ? ${key} then [ { key = name; } ] else [ ]
            ) resolution.names;
        });

        evalResult = {
          inherit resolution;

          eval = optionsType.check options (evalModules {
            inherit options resolution;
            cache = mapAttrs (_: result: removeAttrs result diff) prevEval.eval;
          });

          override = mkOverride root evalResult;
        };
      in
      evalResult
    );

  # Note: root module not type checked as we want to avoid tree traversal.
  eval =
    { root, options }:
    let
      resolution = resolveModules root (attrNames options);

      evalResult = {
        inherit resolution;

        eval = optionsType.check options (evalModules {
          inherit options resolution;
        });

        override = mkOverride root evalResult;
      };
    in
    evalResult;

in
eval
