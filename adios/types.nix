{ korora }:

let
  inherit (builtins) isString;
  inherit (types)
    attrsOf
    union
    struct
    optionalAttr
    string
    never
    function
    type
    any
    modules
    ;

  neverAttr = optionalAttr never;

  typesT = attrsOf modules.typedef;

  types = korora // {
    modules = rec {
      typedef =
        types.typedef' "typedef"
          (union [
            function
            type
            typesT
          ]).verify;

      option =
        (struct "option" {
          inherit type;
          default = optionalAttr any;
          defaultFunc = optionalAttr types.function;
          description = optionalAttr string;
        }).override
          {
            verify =
              option:
              if option ? default && option ? defaultFunc then
                "'default' & 'defaultFunc' are mutually exclusive"
              else
                null;
          };

      subOptions = struct "subOptions" {
        inherit options;
        description = optionalAttr string;
        # Make fields used for normal options non-permitted
        type = neverAttr;
        default = neverAttr;
        defaultFunc = neverAttr;
      };

      options = attrsOf (union [
        modules.option
        modules.subOptions
      ]);

      input = types.option (
        attrsOf (
          struct "input" {
            # Note: The lack of a type for an input means no type checking done.
            type = optionalAttr type;
            # TODO: Narrow permitted chars
            path = types.typedef "pathstring" isString;
          }
        )
      );

      inputs = attrsOf input;

      lib = types.attrs;

      moduleDef =
        (struct "moduleDef" {
          name = optionalAttr string;
          modules = optionalAttr (attrsOf module);
          types = optionalAttr typesT;
          impl = optionalAttr function;
          options = optionalAttr options;
          inputs = optionalAttr inputs;
        }).override
          {
            verify =
              self:
              (if self ? type && self ? options then "'type' is mutually exclusive with 'options'" else null);
          };

      module = struct "module" {
        name = optionalAttr string;
        modules = attrsOf module;
        types = typesT;
        inherit options;
        inherit type;
        inherit inputs;
        __functor = optionalAttr function;
      };
    };
  };

in
types
