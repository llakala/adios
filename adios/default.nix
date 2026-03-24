let
  types = import ./types.nix {
    korora = import ../korora;
  };

  # Helper functions for users, accessed through `adios.lib`
  lib = {
    importModules = import ./lib/importModules.nix { inherit adios; };
    merge = {
      lists.concat = { mutators }: concatLists (attrValues mutators);
      strings.concatLines = { mutators }: concatStringsSep "\n" (attrValues mutators);
      attrs.flat = import ./lib/merge-attrs-flat.nix;
      attrs.recursively = import ./lib/merge-attrs-recursively.nix;
      general.withPrio = import ./lib/withPrio.nix;
    };
  };

  inherit (builtins)
    attrNames
    attrValues
    concatLists
    concatMap
    concatStringsSep
    filter
    foldl'
    functionArgs
    genericClosure
    head
    intersectAttrs
    isString
    listToAttrs
    mapAttrs
    split
    substring
    tail
    ;

  optionalAttrs = cond: attrs: if cond then attrs else { };
  optionals = cond: list: if cond then list else [ ];

  # Call a function with only it's supported attributes.
  callFunction = fn: attrs: fn (intersectAttrs (functionArgs fn) attrs);

  printList = list: "[${concatStringsSep ", " list}]";

  # Check a single type with error prefix
  checkType =
    errorPrefix: type: value:
    let
      err = type.verify value;
    in
    if err == null then value else throw "${errorPrefix}: ${err}";

  # Lazy type check an attrset
  checkAttrsOfType =
    errorPrefix: type: value:
    checkType errorPrefix types.attrs (
      mapAttrs (name: checkType (errorPrefix + "in attribute '${name}'") type) value
    );

  checkOption =
    errorPrefix: option: value:
    let
      err = option.type.verify value;
    in
    if err != null then throw "${errorPrefix}: type error: ${err}" else value;

  # Compute options from defaults & provided args
  computeOptions =
    {
      # Computed args fixpoint
      args,
      # Error prefix string
      errorPrefix,
      # Defined options
      options,
      # Passed options
      passedArgs,
      modulePath,
      root ? null,
    }:
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
          errorPrefix' = "${errorPrefix}: in option '${name}'";
        in
        # Gross hack - if you want to always go through the mergeFunc,
        # set `mutators = []`.
        if option ? mutators then
          assert root != null;
          [
            {
              inherit name;
              value = checkOption errorPrefix' option (
                callFunction option.mergeFunc (
                  args
                  // {
                    mutators = getMutators {
                      inherit
                        name
                        option
                        passedArgs
                        root
                        modulePath
                        ;
                      errorPrefix = errorPrefix';
                    };
                  }
                )
              );
            }
          ]
        # Compute nested options
        else if option ? options then
          let
            value = computeOptions {
              inherit args modulePath root;
              errorPrefix = errorPrefix';
              options = option.options;
              passedArgs = passedArgs.${name} or { };
            };
          in
          # Only return a value if suboptions actually returned anything
          if value != { } then [ { inherit name value; } ] else [ ]
        # Explicitly passed value
        else if passedArgs ? ${name} then
          [
            {
              inherit name;
              value = checkOption errorPrefix' option passedArgs.${name};
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
              value = checkOption errorPrefix' option (callFunction option.defaultFunc args);
            }
          ]
        else
          [ ]
      ) (attrNames options)
    );

  # Type check a module lazily
  loadModule =
    let
      recurse =
        path: def:
        let
          errorPrefix = "in module '${path}'";
        in
        {
          options = checkAttrsOfType "${errorPrefix} options definition" types.modules.option (
            def.options or { }
          );

          modules = mapAttrs (name: recurse "${path}/${name}") (def.modules or { });

          types = checkAttrsOfType "${errorPrefix}: while checking 'types'" types.modules.typedef (
            def.types or { }
          );

          inputs = checkAttrsOfType "${errorPrefix}: while checking 'inputs'" types.modules.input (
            def.inputs or { }
          );

          path = if path == "" then "/" else path;
        }
        // (optionalAttrs (def ? mutations) {
          mutations =
            checkAttrsOfType "${errorPrefix}: while checking 'mutations'" types.modules.mutation
              def.mutations;
        })
        // (optionalAttrs (def ? impl) {
          impl = checkType "${errorPrefix}: while checking 'impl'" types.function def.impl;
        })
        // (optionalAttrs (def ? lib) {
          lib = checkType "${errorPrefix}: while checking 'lib'" types.modules.lib def.lib;
        });
    in
    # The loaded module instance
    recurse "";

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
  fetchModule =
    scope: name:
    assert name != "";
    if name == "/" then
      scope
    else
      let
        tokens = splitString "/" name;
      in
      # Assert that module input begins with a /
      if head tokens != "" then
        throw ''
          Module path `${name}` does not start with a slash.
          Module paths should look like "/nixpkgs", which refers to `root.modules.nixpkgs`.
        ''
      else
        foldl' (
          module: tok:
          if !module.modules ? ${tok} then
            throw ''
              Module path `${tok}` is not a child module of `${module.path}`.
              Valid children of `${module.path}`: [${concatStringsSep ", " (attrNames module.modules)}]
            ''
          else
            module.modules.${tok}
        ) scope (tail tokens);

  getMutators =
    {
      name,
      option,
      passedArgs,
      root,
      modulePath,
      errorPrefix,
    }:
    listToAttrs (
      concatMap (
        mutatorPath':
        let
          mutatorPath = absModulePath modulePath mutatorPath';
          resolution = fetchModule root mutatorPath;
        in
        # TODO: decide whether to error here, if a module didn't
        # mutate when it was supposed to
        if resolution.mutations ? ${modulePath}.${name} then
          [
            {
              name = mutatorPath;
              value = checkOption "${errorPrefix}: while checking type of mutator '${mutatorPath}'" {
                type = option.mutatorType;
              } (callFunction resolution.mutations.${modulePath}.${name} resolution.args);
            }
          ]
        else
          [ ]
      ) option.mutators
      # If the mutators list is nonempty, have the value passed in eval stage
      # option go through the mergeFunc, under the current module's name.
      ++ optionals (passedArgs ? ${name}) [
        {
          name = modulePath;
          value = checkOption "${errorPrefix}: while checking type of injected value" {
            type = option.mutatorType;
          } passedArgs.${name};
        }
      ]
    );

  # Resolve required module dependencies for defined config options
  resolveTree =
    scope: moduleNames:
    listToAttrs (
      map
        (x: {
          name = x.key;
          value = fetchModule scope x.key;
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
            }) (attrValues (fetchModule scope key).inputs);
        })
    );

  # When inspecting the args passed to a module within an `impl` or
  # `defaultFunc`, include the functor to call the module's impl directly.
  inspectImpl =
    module: oldArgs:
    if module ? impl then
      oldArgs
      // {
        __functor = _: newArgs: module newArgs;
      }
    else
      oldArgs;

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
          options = computeOptions {
            inherit modulePath;
            inherit (module) options;
            args = args.${modulePath};
            errorPrefix = "while computing eval stage: while computing '${modulePath}' args";
            passedArgs = options.${modulePath} or { };
          };
        }) resolution
        // memoArgs;

      # Module call results for each callable module in resolution
      # TODO: actually use this
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
                  value = callFunction module.impl args.${modulePath};
                }
              ]
            else
              [ ]
          ) (attrNames resolution)
        )
        // memoResults;
    };

  computeArgs =
    {
      root,
      module,
      # Options to be injected
      passedArgs,
    }:
    let
      args = {
        inputs = mapAttrs (
          _: input:
          let
            inputPath = absModulePath module.path input.path;
            inputModule = fetchModule root inputPath;
          in
          inputModule.args.options
          // optionalAttrs (inputModule ? impl) {
            __functor =
              _: implOptions:
              let
                args =
                  # Reuse existing args if impl isn't being passed anything new
                  if implOptions == { } then
                    inputModule.args
                  else
                    # If any new args are passed, recompute the options, so any
                    # defaultFuncs are updated
                    {
                      inherit (inputModule.args) inputs;
                      options = computeOptions {
                        inherit args root;
                        inherit (inputModule) options;
                        errorPrefix = "while computing '${module.path}' args: while calling input '${module.path}'";
                        modulePath = inputPath;
                        passedArgs = implOptions;
                      };
                    };
              in
              callFunction inputModule.impl args;
          }
        ) module.inputs;
        options = inspectImpl module (computeOptions {
          inherit args root;
          modulePath = module.path;
          inherit (module) options;
          errorPrefix = "while computing '${module.path}' args";
          passedArgs = passedArgs.${module.path} or { };
        });
      };
    in
    args;

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
        # Current module
        module:
        let
          self =
            module
            // {
              # Take args from resolved context if it's available there.
              args =
                args.${module.path} or (computeArgs {
                  module = self;
                  root = tree';
                  passedArgs = options;
                });
              # Recurse into child modules
              modules = mapAttrs (_: recurse) module.modules;
            }
            // optionalAttrs (module ? impl) {
              # Wrap module call with computed args
              __functor =
                _: implOptions:
                let
                  passedOptions = options.${module.path} or { };
                  args =
                    if implOptions == { } then
                      # Reuse existing args if impl isn't being passed anything new
                      self.args
                    else
                      # Re-compute args fixpoint with passed args
                      {
                        inherit (self.args) inputs;
                        options = inspectImpl self (computeOptions {
                          inherit args;
                          modulePath = module.path;
                          inherit (module) options;
                          root = tree';
                          errorPrefix = "while calling '${module.path}'";
                          # Concat passed options with options passed to tree eval
                          passedArgs = mergeOptionsUnchecked self.options passedOptions implOptions;
                        });
                      };
                in
                # Call implementation
                callFunction self.impl args;
            };
        in
        self;

      tree' = recurse root;
    in
    tree';

  # Load a module tree recursively from root module
  loadTree =
    unloadedRoot:
    let
      root = loadModule unloadedRoot;
    in
    {
      options ? { },
    }:
    let
      resolution = resolveTree root (attrNames options);
      evalParams = evalModuleTree { inherit resolution options; };
    in
    # Tree context
    applyTreeOptions {
      inherit root options;
      inherit (evalParams) args;
    };

  adios =
    (loadModule {
      inherit types lib;
    })
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: loadTree;
    };

in
adios
