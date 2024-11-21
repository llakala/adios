{
  types,
  lib,
  adios,
}:

let
  inherit (builtins)
    groupBy
    mapAttrs
    length
    head
    attrNames
    isAttrs
    concatMap
    listToAttrs
    typeOf
    ;
  inherit (lib) throwIf isDerivation;

  # Subset of the module type
  checkedModule = types.struct "checkedModule" {
    inherit (adios.interfaces) name checks;
  };

  findPrefix = set: prefix: if !set ? prefix then prefix else (findPrefix set "_${prefix}");

  recurseModule =
    module:
    module.checks
    // {
      ${findPrefix module.checks "modules"} = mapAttrs (_name: recurseModule) module.modules;
    };

  flattenTree' =
    prefix: tree:
    concatMap (
      name:
      let
        value = tree.${name};
      in
      if isDerivation value then
        [
          {
            name = "${prefix}${name}";
            inherit value;
          }
        ]
      else if isAttrs value then
        (flattenTree' "${prefix}${name}_" value)
      else
        throw "Unhandled type: ${typeOf value}"
    ) (attrNames tree);

  flattenTree = tree: listToAttrs (flattenTree' "check_" tree);

in

{
  name = "checks";

  options = {
    modules = {
      type = types.listOf checkedModule;
    };

    flat = {
      type = types.bool;
      default = true;
    };
  };

  impl =
    args:
    let
      tree = mapAttrs (
        name: group:
        throwIf (length group > 1) "checks: name collision for module: ${name}" (recurseModule (head group))
      ) (groupBy (mod: mod.name) args.modules);
    in
    if args.flat then
      {
        checks = flattenTree tree;
      }
    else
      {
        checks = tree;
      };

}
