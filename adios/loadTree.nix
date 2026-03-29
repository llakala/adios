# Types from adios
types:
# Self-reference for the result of this file
tree:
# Directly passed values for options in the eval stage
evalParams:
let
  inherit (builtins)
    attrNames
    concatMap
    concatStringsSep
    filter
    foldl'
    functionArgs
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
    # Defined options
    options:
    # Path from root of the current module
    modulePath:
    # Computed args fixpoint
    args:
    # Error prefix string
    errorPrefix:
    # parameters given explicitly in eval/impl stage
    params:
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
          [
            {
              inherit name;
              value = checkOption errorPrefix' option (
                callFunction option.mergeFunc (
                  args
                  // {
                    mutators = computeMutators modulePath errorPrefix' name option params;
                  }
                )
              );
            }
          ]
        # Compute nested options
        else if option ? options then
          let
            value = computeOptions option.options modulePath args errorPrefix' (params.${name} or { });
          in
          # Only return a value if suboptions actually returned anything
          if value != { } then [ { inherit name value; } ] else [ ]
        # Explicitly passed value
        else if params ? ${name} then
          [
            {
              inherit name;
              value = checkOption errorPrefix' option params.${name};
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

  computeMutators =
    modulePath: errorPrefix: name: option: params:
    listToAttrs (
      concatMap (
        mutatorPath':
        let
          mutatorPath = absModulePath modulePath mutatorPath';
          resolution = fetchModule mutatorPath;
        in
        # TODO: decide whether to error here, if a module didn't
        # mutate when it was supposed to
        if resolution.mutations ? ${modulePath}.${name} then
          [
            {
              name = mutatorPath;
              value =
                checkType "${errorPrefix}: while checking type of mutator '${mutatorPath}'" option.mutatorType
                  (callFunction resolution.mutations.${modulePath}.${name} resolution.args);
            }
          ]
        else
          [ ]
      ) option.mutators
      # If the mutators list is nonempty, have the value passed in eval/impl
      # stage go through the mergeFunc, under the current module's name.
      ++ optionals (params ? ${name}) [
        {
          name = modulePath;
          value =
            checkType "${errorPrefix}: while checking type of injected value" option.mutatorType
              params.${name};
        }
      ]
    );

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
    pwd: path: if substring 0 1 path == "/" then path else toString (/. + pwd + "/${path}");

  # Get a module by it's / delimited path from the tree root
  fetchModule =
    name:
    assert name != "";
    if name == "/" then
      tree
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
              Valid children of `${module.path}`: ${printList (attrNames module.modules)}
            ''
          else
            module.modules.${tok}
        ) tree (tail tokens);

  recurse =
    path: def:
    let
      errorPrefix = "in module '${path}'";
      computeModuleOptions = computeOptions self.options self.path;
      self = {
        path = if path == "" then "/" else path;
        options = checkAttrsOfType "${errorPrefix}: while checking 'options'" types.modules.option (
          def.options or { }
        );
        inputs = checkAttrsOfType "${errorPrefix}: while checking 'inputs'" types.modules.input (
          def.inputs or { }
        );
        mutations = checkAttrsOfType "${errorPrefix}: while checking 'mutations'" types.modules.mutation (
          def.mutations or { }
        );
        modules = mapAttrs (name: recurse "${path}/${name}") (def.modules or { });
        args = {
          inputs = mapAttrs (
            _: input: (fetchModule (absModulePath self.path input.path)).args.options
          ) self.inputs;
          options =
            computeModuleOptions self.args "while computing '${self.path}' args" (
              evalParams.${self.path} or { }
            )
            # If the current module has an impl, include it in the computed args,
            # so the module can be called inside the tree
            // (if def ? impl then { inherit (self) __functor; } else { });
        };
      }
      // optionalAttrs (def ? lib) {
        lib = checkType "${errorPrefix}: while checking 'lib'" types.modules.lib def.lib;
      }
      // optionalAttrs (def ? types) {
        types = checkAttrsOfType "${errorPrefix}: while checking 'types'" types.modules.typedef def.types;
      }
      // (optionalAttrs (def ? impl) {
        impl = checkType "${errorPrefix}: while checking 'impl'" types.function def.impl;
        __functor =
          _: implParams:
          let
            args =
              if implParams == { } then
                # Reuse existing args if impl isn't being passed anything new
                self.args
              else
                # Recompute args fixpoint with passed params
                {
                  inherit (self.args) inputs;
                  options =
                    computeModuleOptions args "while calling '${self.path}'" (
                      if evalParams ? ${self.path} then
                        mergeOptionsUnchecked self.options evalParams.${self.path} implParams
                      else
                        implParams
                    )
                    # Current module necessarily defines a functor - include
                    # it in the computed args
                    // {
                      inherit (self) __functor;
                    };
                };
          in
          # Call implementation
          callFunction self.impl args;
      });
    in
    self;
in
recurse ""
