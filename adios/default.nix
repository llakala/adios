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
  inherit (types) struct;

  optionalAttrs = cond: attrs: if cond then attrs else { };

  # Transform options into a default value attrset
  optionsToDefaults =
    errorPrefix: options:
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
        in
        if option ? default then
          [
            rec {
              inherit name;
              value =
                if err != null then "${errorPrefix}: in option '${name}': type error ${err}" else option.default;
              err = option.type.verify option.default;
            }
          ]
        else if option ? options then
          [
            {
              inherit name;
              value = optionsToDefaults "${errorPrefix}: in option '${name}'" option.options;
            }
          ]
        else
          [ ]
      ) (attrNames options)
    );

  # Update default values with new ones
  updateDefaults =
    errorPrefix: options: old: new:
    old
    // mapAttrs (
      name: value:
      if !options ? ${name} then
        throw "${errorPrefix}: applied option '${name}' does not exist"
      else
        let
          option = options.${name};
          err = option.type.verify value;
        in
        if option ? options then
          updateDefaults "${errorPrefix}: in option ${name}" option.options (old.${name} or { }) value
        else if err != null then
          throw "${errorPrefix}: in option '${name}': type error ${err}"
        else
          value
    ) new;

  computeDefaults =
    args': options: defaults:
    listToAttrs (
      concatMap (
        name:
        let
          option = options.${name};
        in
        if option ? defaultFunc then
          (
            if defaults ? ${name} then
              [ ] # Explicitly passed, no need to compute
            else
              [
                {
                  # Compute value with args fixpoint
                  inherit name;
                  value = option.defaultFunc args';
                }
              ]
          )
        else if option ? options then
          let
            value = computeDefaults args' options.${name} (defaults.${name} or { });
          in
          # Only return an updated value if suboptions were actually computed anything
          if value != { } then [ { inherit name value; } ] else [ ]
        else
          [ ]
      ) (attrNames options)
    );

  # Transform options into a concrete struct type
  optionsToType =
    name: options:
    struct name (
      mapAttrs (
        name: option: if option ? options then optionsToType name option.options else option.type
      ) options
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

      options' = checkOptionsType "${errorPrefix} options definition" (def.options or { });

      # Transform options into an attrset of default values
      defaults = updateDefaults errorPrefix options' (optionsToDefaults errorPrefix options') updates;

      # The loaded module instance
      mod = {
        inherit name;

        options = options';

        apply = updates': apply def (updates // updates');

        modules = mapAttrs (_: load) (def.modules or { });

        types = checkAttrsOf "${errorPrefix}: while checking 'types'" types.modules.typedef (
          def.types or { }
        );

        interfaces = checkAttrsOf "${errorPrefix}: while checking 'interfaces'" types.modules.typedef (
          def.interfaces or { }
        );

        type =
          def.type or (
            if def ? options then
              # Transform options into a struct type
              optionsToType name options'
            else
              types.never
          );

      }
      // (optionalAttrs (def ? impl) {
        # Wrap implementation with an options typechecker
        __functor =
          _: args:
          let
            # Concat provided args with statically defined defaults
            defaults' = updateDefaults "while calling module '${name}'" options' defaults args;
            # Compute dynamically defined defaults using defaultFunc
            args' = updateDefaults "while calling module '${name}'" options' defaults' (
              computeDefaults args' options' defaults'
            );
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

      type = types.union [
        types.modules.moduleDef
        types.function
      ];

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
