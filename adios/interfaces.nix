{ types }:

let
  inherit (types)
    attrsOf
    struct
    optionalAttr
    string
    union
    listOf
    derivation
    ;

in
{
  /*
    A name
    .
  */
  name = types.string;

  /*
    UNIX file permissions
    .
  */
  unixPerms = attrsOf (
    struct "unixPerms" {
      owner = optionalAttr string;
      group = optionalAttr string;
      permissions = optionalAttr string;
    }
  );

  /*
    A derivation
    .
  */
  package = derivation;

  /*
    List of derivations
    .
  */
  packages = listOf derivation;

  /*
    A package set
    .
  */
  pkgs = types.attrs;

  /*
    NixOS configuration to enable when rendering module into NixOS system
    .
  */
  nixos = union [
    types.attrs
    types.function
  ];
}
