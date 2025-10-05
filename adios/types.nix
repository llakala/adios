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

  nixUnitTest' =
    (struct "nixUnitTest" {
      expr = types.any;

      expected = optionalAttr types.any;
      expectedError = optionalAttr (
        (struct "expectedError" {
          type = optionalAttr string;
          msg = optionalAttr string;
        }).override
          {
            verify =
              expectedError:
              if !(expectedError ? type) && !(expectedError ? msg) then
                "requires either attribute type or msg"
              else
                null;
          }
      );
    }).override
      {
        verify =
          test:
          if !(test ? expected) && !(test ? expectedError) then
            "requires either attribute expected or expectedError"
          else
            null;
      };

  nixUnitTests = attrsOf types.modules.nixUnitTest;

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

      nixUnitTest =
        types.typedef' "nixUnitTests"
          (union [
            nixUnitTest'
            nixUnitTests
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

      checks =
        types.typedef' "checks"
          (attrsOf (union [
            types.derivation
            types.modules.checks
          ])).verify;

      moduleDef =
        (struct "moduleDef" {
          name = optionalAttr string;
          modules = optionalAttr (attrsOf module);
          types = optionalAttr typesT;
          interfaces = optionalAttr (attrsOf type);
          impl = optionalAttr function;
          checks = optionalAttr checks;
          tests = optionalAttr nixUnitTests;
          options = optionalAttr options;
          type = optionalAttr type;
        }).override
          {
            verify =
              self:
              (
                if self ? type && self ? options then
                  "'type' is mutually exclusive with 'options'"
                else if self ? options && !(self ? impl) then
                  "has 'options' but no 'impl' provided"
                else
                  null
              );
          };

      module = struct "module" {
        name = string;
        modules = attrsOf module;
        inherit checks;
        types = typesT;
        interfaces = typesT;
        inherit options;
        inherit type;
        tests = nixUnitTests;
        __functor = function;
      };

      moduleInstance = struct "moduleInstance" {
        name = optionalAttr string;
      };
    };
  };

in
types
