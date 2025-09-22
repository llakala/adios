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
    isFunction
    typeOf
    functionArgs
    ;
  inherit (types) struct;

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
    moduleDef: updates:
    let
      # Call moduleDef with declared arguments
      args' = {
        inherit adios types;
        self = mod;
      };
      def =
        if isFunction moduleDef then
          moduleDef (
            mapAttrs (n: _: args'.${n} or (throw "Module takes argument '${n}' which is unknown")) (
              functionArgs moduleDef
            )
          )
        else if isAttrs moduleDef then
          moduleDef
        else
          throw "expected module definition to be either of type 'function' or 'set', was ${typeOf moduleDef}";

      name' = def.name or "<anonymous>";
      name = types.string.check name' name';

      errorPrefix = "in module '${name}'";

      options' = checkOptionsType "${errorPrefix} options definition" (def.options or { });

      # Transform options into an attrset of default values
      defaults =
        updateDefaults errorPrefix options' (optionsToDefaults errorPrefix options')
          updates.options;

      # The loaded module instance
      mod = {
        inherit name;

        options = options';

        apply =
          {
            options ? { },
            inputs ? { },
          }:
          apply moduleDef {
            options = updates.options // options;
            inputs = updates.inputs // inputs;
          };

        modules = mapAttrs (_: load) (def.modules or { });

        types = checkAttrsOf "${errorPrefix}: while checking 'types'" types.modules.typedef (
          def.types or { }
        );

        interfaces = checkAttrsOf "${errorPrefix}: while checking 'interfaces'" types.modules.typedef (
          def.interfaces or { }
        );

        checks = checkAttrsOf "${errorPrefix}: while checking 'checks'" types.derivation (
          def.checks or { }
        );

        tests = checkAttrsOf "${errorPrefix}: while checking 'tests'" types.modules.nixUnitTest (
          def.tests or { }
        );

        inputs = checkAttrsOf "${errorPrefix}: while checking 'inputs'" types.modules.inputs (
          def.inputs or { }
        );

        lib = checkAttrsOf "${errorPrefix}: while checking 'lib'" types.modules.lib (def.lib or { });

        override =
          newDef:
          apply (
            if isFunction newDef then
              newDef def
            else if isAttrs newDef then
              newDef
            else
              throw "expected override module definition to be either of type 'function' or 'set', was ${typeOf newDef}"
          ) updates;

        # Given arguments options & inputs
        args =
          {
            options ? { },
            inputs ? { },
          }:
          let
            # Concat provided args with statically defined defaults
            defaults' = updateDefaults "${errorPrefix}: while computing options" options' defaults options;
            inputs' = updates.inputs // inputs;

            self = {
              # Compute dynamically defined defaults using defaultFunc
              options = updateDefaults "${errorPrefix}: while computing options" options' defaults' (
                computeDefaults self options' defaults'
              );

              # Create a narrowed type checked view of inputs
              inputs = mapAttrs (
                name: fields:
                if fields == null then
                  inputs'.${name}
                else
                  (
                    let
                      input = inputs'.${name};
                    in
                    mapAttrs (
                      fieldName: field:
                      let
                        value = input.${fieldName};
                        err = field.type.verify value;
                      in
                      if err == null then
                        value
                      else
                        throw "${errorPrefix}: while computing 'inputs.${name}.${fieldName}': ${err}"
                    ) fields
                  )
              ) mod.inputs;
            };
          in
          self;

        type =
          def.type or (
            if def ? options then
              # Transform options into a struct type
              optionsToType name options'
            else
              types.never
          );
      }
      // (
        if def ? impl then
          {
            __functor =
              self:
              {
                options ? { },
                inputs ? { },
                __checked ? false,
              }:
              def.impl (
                # If the value is already checked, skip checking it again.
                if !__checked then self.args { inherit options inputs; } else { inherit options inputs; }
              );
          }
        else
          { }
      );
    in
    mod;

  load =
    moduleDef:
    apply moduleDef {
      options = { };
      inputs = { };
    };

  interfaces = import ./interfaces.nix { inherit types; };

  adios =
    (load (_: {
      name = "adios";
      inherit types interfaces;
      tests = import ./tests.nix { inherit adios; };

      type = types.union [
        types.modules.moduleDef
        types.function
      ];

      lib = import ./lib.nix;

      modules = {
        nix-unit = import ./modules/nix-unit.nix;
        checks = import ./modules/checks.nix;
      };
    }))
    // {
      # Overwrite default functor with one that _does not_ do type checking.
      # `load` does it's own type checking.
      __functor = _: load;
    };

in
adios
