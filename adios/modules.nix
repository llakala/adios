{ types }:
let
  inherit (builtins)
    attrNames
    listToAttrs
    mapAttrs
    concatMap
    isAttrs
    filter
    isString
    split
    head
    tail
    foldl'
    substring
    concatStringsSep
    intersectAttrs
    functionArgs
    ;

  optionalAttrs = cond: attrs: if cond then attrs else { };

  # Split string by separator
  splitString = sep: s: filter isString (split sep s);

  self = {
    # Default in error messages when no name is provided
    anonymousModuleName = "<anonymous>";

    # A coarse grained options type for input validation
    optionsType = types.attrsOf types.attrs;

    # Call a function with only it's supported attributes.
    callFunction = fn: attrs: fn (intersectAttrs (functionArgs fn) attrs);

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
      computedArgs:
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
                value = checkOption errorPrefix' option (self.callFunction option.defaultFunc computedArgs);
              }
            ]
          # Compute nested options
          else if option ? options then
            let
              value = self.computeOptions computedArgs errorPrefix' options.${name} (args.${name} or { });
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
          { options = self.checkOptionsType "${errorPrefix}: in option '${name}'" option.options; }
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
        mapAttrs (name: self.checkAttrsOf "${errorPrefix}: in attr '${name}'" type) value
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
        options = self.checkOptionsType "${errorPrefix} options definition" (def.options or { });

        modules = mapAttrs (_: self.loadModule) (def.modules or { });

        lib = self.checkType "${errorPrefix}: while checking 'lib'" types.modules.lib (def.lib or { });

        types = self.checkAttrsOf "${errorPrefix}: while checking 'types'" types.modules.typedef (
          def.types or { }
        );

        providers = self.checkAttrsOf "${errorPrefix}: while checking 'providers'" types.modules.providers (
          def.providers or { }
        );

        inputs = self.checkAttrsOf "${errorPrefix}: while checking 'inputs'" types.modules.input (
          def.inputs or { }
        );
      }
      // (optionalAttrs (def ? name) {
        name = self.checkType "${errorPrefix}: while checking 'name'" types.string def.name;
      })
      // (optionalAttrs (def ? impl) {
        impl = self.checkType "${errorPrefix}: while checking 'impl'" types.function def.impl;

        # Make contract callable
        __functor =
          moduleSelf:
          {
            options ? { },
            inputs ? { },
          }:
          let
            args' = self.computeOptions args' errorPrefix moduleSelf.options { inherit options inputs; };
          in
          self.callFunction moduleSelf.impl args';
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
                value = self.mergeOptionsUnchecked option.options (lhs.${optionName} or { }) (
                  rhs.${optionName} or { }
                );
              }
            ]
          else
            [ ]
        ) (attrNames options)
      );

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
        if head tokens != "" then
          throw ''
            Module path `${name}` didn't start with a slash, when it was expected to.
            This likely means you used the incorrect name during the eval stage.
            A module path should look something like "/nixpkgs", which refers to `root.modules.nixpkgs`,
            and lets us set the options for that module.
          ''
        else
          foldl' (
            module: tok:
            if !module.modules ? ${tok} then
              throw ''
                Module path `${tok}` wasn't a child module of `${module.name or self.anonymousModuleName}`.
                Valid children of `${module.name}`: [${concatStringsSep ", " (attrNames module.modules)}]
              ''
            else
              module.modules.${tok}
          ) module (tail tokens);
  };
in
self
