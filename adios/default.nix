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
    ;

  optionalAttrs = cond: attrs: if cond then attrs else { };

  computeOptions =
    let
      checkOption =
        errorPrefix: option: value:
        let
          err = option.type.verify value;
        in
        if err != null then (throw "${errorPrefix}: ${err}") else value;
    in
    # Options fixpoint
    options':
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
              value = checkOption errorPrefix' option (option.defaultFunc options');
            }
          ]
        # Compute nested options
        else if option ? options then
          let
            value = computeOptions options' errorPrefix' options.${name} (args.${name} or { });
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

      interfaces = checkAttrsOf "${errorPrefix}: while checking 'interfaces'" types.modules.typedef (
        def.interfaces or { }
      );
    }
    // (optionalAttrs (def ? name) {
      name = checkType "${errorPrefix}: while checking 'name'" types.string def.name;
    })
    // (optionalAttrs (def ? impl) {
      impl = checkType "${errorPrefix}: while checking 'impl'" types.function def.impl;

      # Wrap implementation with an options typechecker
      __functor =
        self: args:
        let
          args' = computeOptions args' errorPrefix self.options args;
        in
        self.impl args';
    });

  interfaces = import ./interfaces.nix { inherit types; };

  adios =
    (loadModule {
      name = "adios";
      inherit types interfaces;

      lib = {
        load = root: {
          root = loadModule root;
        };
      };
    })
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: loadModule;
    };

in
adios
