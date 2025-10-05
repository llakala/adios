{ korora }:

let
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

      lib = types.attrs;

      moduleDef =
        (struct "moduleDef" {
          name = optionalAttr string;
          modules = optionalAttr (attrsOf module);
          types = optionalAttr typesT;
          interfaces = optionalAttr (attrsOf type);
          impl = optionalAttr function;
          options = optionalAttr options;
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
        interfaces = typesT;
        inherit options;
        inherit type;
        __functor = optionalAttr function;
      };
    };
  };

in
types
