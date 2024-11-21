{
  types,
  adios,
  lib,
  ...
}:

let
  inherit (adios) interfaces;

  hasInterface =
    interfaces: name:
    let
      type = interfaces.${name};
    in
    module:
    if module ? ${name} then
      (
        let
          err = type.verify module.${name};
        in
        if err == null then true else throw "error checking type for interface '${name}': ${err}"
      )
    else
      false;

  hasPackage = hasInterface interfaces "package";
  hasPackages = hasInterface interfaces "packages";

in

{
  name = "nixos";

  options = {
    modules = {
      type = types.listOf types.modules.moduleInstance;
    };
  };

  impl = options: {
    name = "nixos";

    nixos = {
      config = lib.mkMerge (
        map (
          mod:
          lib.mkMerge [
            (
              if hasPackage mod then
                {
                  environment.systemPackages = [ mod.package ];
                }
              else
                { }
            )

            (
              if hasPackages mod then
                {
                  environment.systemPackages = mod.packages;
                }
              else
                { }
            )
          ]
        ) options.modules
      );
    };
  };
}
