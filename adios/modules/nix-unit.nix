{
  types,
  adios,
}:

let
  inherit (builtins)
    groupBy
    mapAttrs
    length
    head
    ;
  throwIf = cond: msg: if cond then throw msg else x: x;

  # Subset of the module type
  testedModule = types.struct "testedModule" {
    inherit (adios.interfaces) name;
    modules = types.attrsOf testedModule;
    tests = types.modules.nixUnitTest;
  };

  findPrefix = set: prefix: if !set ? prefix then prefix else (findPrefix set "_${prefix}");

  recurseModule =
    module:
    module.tests
    // {
      ${findPrefix module.tests "modules"} = mapAttrs (_: recurseModule) module.modules;
    };

in

{
  name = "nix-unit";

  options = {
    modules = {
      type = types.listOf testedModule;
    };
  };

  impl = args: {
    nixUnitTests = mapAttrs (
      name: group:
      throwIf (length group > 1) "nix-unit: name collision for module: ${name}" (
        recurseModule (head group)
      )
    ) (groupBy (mod: mod.name) args.modules);
  };

}
