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
        if err != null then throw "${errorPrefix}: ${err}" else value;
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

  # Apply one or more defaults to module.
  apply =
    def: updates:
    let
      name' = def.name or "<anonymous>";
      name = types.string.check name' name';

      errorPrefix = "in module '${name}'";

      # The loaded module instance
      mod = {
        options = checkOptionsType "${errorPrefix} options definition" (def.options or { });

        apply = updates': apply def (updates // updates');

        modules = mapAttrs (_: load) (def.modules or { });

        lib =
          if def ? lib then
            (
              let
                type = types.modules.lib;
                err = type.verify def.lib;
              in
              if err != null then (throw "${errorPrefix}: while checking 'lib': ${err}") else def.lib
            )
          else
            { };

        types = checkAttrsOf "${errorPrefix}: while checking 'types'" types.modules.typedef (
          def.types or { }
        );

        interfaces = checkAttrsOf "${errorPrefix}: while checking 'interfaces'" types.modules.typedef (
          def.interfaces or { }
        );
      }
      // (optionalAttrs (def ? name) {
        inherit (def) name;
      })
      // (optionalAttrs (def ? impl) {
        # Wrap implementation with an options typechecker
        __functor =
          self: args:
          let
            args' = computeOptions args' errorPrefix self.options args;
          in
          def.impl args';
      });

    in
    mod;

  load = moduleDef: apply moduleDef { };

  interfaces = import ./interfaces.nix { inherit types; };

  adios =
    (load {
      name = "adios";
      inherit types interfaces;

      modules = {
        nix-unit = import ./modules/nix-unit.nix;
      };
    })
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: load;
    };

in
adios
