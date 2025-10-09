{
  korora,
}:

let
  types = import ./types.nix { inherit korora; };

  inherit (builtins)
    attrNames
    listToAttrs
    mapAttrs
    concatMap
    isAttrs
    genericClosure
    filter
    isString
    split
    head
    tail
    foldl'
    attrValues
    substring
    concatStringsSep
    ;

  optionalAttrs = cond: attrs: if cond then attrs else { };

  # A coarse grained options type for input validation
  optionsType = types.attrsOf types.attrs;

  # Compute options from defaults & provided args
  computeOptions =
    let
      checkOption =
        errorPrefix: option: value:
        let
          err = option.type.verify value;
        in
        if err != null then (throw "${errorPrefix}: ${err}") else value;
    in
    # Computed args fixpoint
    self:
    # Error prefix string
    errorPrefix:
    # Defined options
    options:
    # Passed options
    args:
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
          errorPrefix' = "${errorPrefix}: in option '${name}'";
        in
        # Explicitly passed value
        if args ? ${name} then
          [
            {
              inherit name;
              value = checkOption errorPrefix' option args.${name};
            }
          ]
        # Default value
        else if option ? default then
          [
            {
              inherit name;
              value = checkOption errorPrefix' option option.default;
            }
          ]
        # Computed default value
        else if option ? defaultFunc then
          [
            {
              # Compute value with args fixpoint
              inherit name;
              value = checkOption errorPrefix' option (option.defaultFunc self);
            }
          ]
        # Compute nested options
        else if option ? options then
          let
            value = computeOptions self errorPrefix' options.${name} (args.${name} or { });
          in
          # Only return a value if suboptions actually returned anything
          if value != { } then [ { inherit name value; } ] else [ ]
        # Nothing passed & no default. Leave unset.
        else
          [ ]
      ) (attrNames options)
    );

  # Lazy typecheck options
  checkOptionsType =
    errorPrefix: options:
    mapAttrs (
      name: option:
      if option ? options then
        { options = checkOptionsType "${errorPrefix}: in option '${name}'" option.options; }
      else
        let
          err = types.modules.option.verify option;
        in
        if err != null then throw "${errorPrefix}: in option '${name}': type error: ${err}" else option
    ) options;

  # Lazy type check an attrset
  checkAttrsOf =
    errorPrefix: type: value:
    let
      err = type.verify value;
    in
    if err == null then
      value
    else if isAttrs value then
      mapAttrs (name: checkAttrsOf "${errorPrefix}: in attr '${name}'" type) value
    else
      throw "${errorPrefix}: in attr: ${err}";

  # Check a single type with error prefix
  checkType =
    errorPrefix: type: value:
    let
      err = type.verify value;
    in
    if err == null then value else throw "${errorPrefix}: ${err}";

  # Type check a module lazily
  loadModule =
    def:
    let
      errorPrefix =
        if def ? name then "in module ${types.string.check def.name def.name}" else "in module";
    in
    # The loaded module instance
    {
      options = checkOptionsType "${errorPrefix} options definition" (def.options or { });

      modules = mapAttrs (_: loadModule) (def.modules or { });

      lib = checkType "${errorPrefix}: while checking 'lib'" types.modules.lib (def.lib or { });

      types = checkAttrsOf "${errorPrefix}: while checking 'types'" types.modules.typedef (
        def.types or { }
      );

      inputs = checkAttrsOf "${errorPrefix}: while checking 'inputs'" types.modules.input (
        def.inputs or { }
      );
    }
    // (optionalAttrs (def ? name) {
      name = checkType "${errorPrefix}: while checking 'name'" types.string def.name;
    })
    // (optionalAttrs (def ? impl) {
      impl = checkType "${errorPrefix}: while checking 'impl'" types.function def.impl;

      # Make contract callable
      __functor =
        self:
        {
          options ? { },
          inputs ? { },
        }:
        let
          args' = computeOptions args' errorPrefix self.options { inherit options inputs; };
        in
        self.impl args';
    });

  # Merge lhs & rhs recursing into suboptions
  mergeOptionsUnchecked =
    options: lhs: rhs:
    lhs
    // rhs
    // listToAttrs (
      concatMap (
        optionName:
        let
          option = options.${optionName};
        in
        if option ? options then
          [
            {
              name = optionName;
              value = mergeOptionsUnchecked option.options (lhs.${optionName} or { }) (rhs.${optionName} or { });
            }
          ]
        else
          [ ]
      ) (attrNames options)
    );

  # Split string by separator
  splitString = sep: s: filter isString (split sep s);

  # Return absolute module path relative to pwd
  absModulePath =
    pwd: path: toString (if substring 0 1 path == "/" then /. + path else /. + pwd + "/${path}");

  # Get a module by it's / delimited path
  getModule =
    module: name:
    assert name != "";
    if name == "/" then
      module
    else
      let
        tokens = splitString "/" name;
      in
      # Assert that module input begins with a /
      assert head tokens == "";
      foldl' (acc: tok: acc.modules.${tok}) module (tail tokens);

  # Resolve required module dependencies for defined config options
  resolveTree =
    scope: moduleNames:
    listToAttrs (
      map
        (x: {
          name = x.key;
          value = getModule scope x.key;
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
              key = absModulePath key input.path;
            }) (attrValues (getModule scope key).inputs);
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
          options = computeOptions args.${modulePath} "while computing ${modulePath} args" module.options (
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
                  value = module.impl args.${modulePath};
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
                _: input: (getModule tree' (absModulePath modulePath input.path)).args.options
              ) module.inputs;
              options = computeOptions args' "while computing ${modulePath} args" module.options (
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
            self: options:
            let
              # Concat passed options with options passed to tree eval
              options' = mergeOptionsUnchecked self.options passedOptions options;
              # Re-compute args fixpoint with passed args
              args = {
                inherit (self.args) inputs;
                options = computeOptions args "while calling ${modulePath}" module.options options';
              };
            in
            # Call implementation
            self.impl args;
        };

      tree' = recurse [ ] root;
    in
    tree';

  mkOverride =
    root: prevEval:
    {
      # Updated options
      options,
      # Whether to allow re-resolving
      resolve ? true,
    }:
    optionsType.check options (
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
                resolveTree root (attrNames options')
              else
                throw ''
                  Module overriding caused re-resolving, which is disabled.
                  Differing modules: ${builtins.concatStringsSep " " newModuleNames}
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
          eval = evalModuleTree {
            inherit resolution;
            options = options';
            memoArgs = removeAttrs prevEval.args diff;
            memoResults = removeAttrs prevEval.results diff;
          };

          # Tree context
          tree = applyTreeOptions {
            inherit root;
            options = options';
            inherit (result.eval) args;
          };

          # Chained override function
          override = mkOverride root result.eval;
        };
      in
      result
    );

  # Load a module tree recursively from root module
  loadTree =
    root:
    let
      root' = loadModule root;
    in
    {
      root = root';

      eval =
        {
          options,
        }:
        optionsType.check options (
          let
            result = {
              # Eval context
              eval =
                let
                  resolution = resolveTree root' (attrNames options);
                in
                evalModuleTree { inherit resolution options; };

              # Tree context
              tree = applyTreeOptions {
                root = root';
                inherit options;
                inherit (result.eval) args;
              };

              # Chained override function
              override = mkOverride root' result.eval;
            };
          in
          result
        );
    };

  adios =
    (loadModule {
      name = "adios";
      inherit types;
    })
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: loadTree;
    };

in
adios
