{
  description = "Adios";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    korora.url = "github:adisbladis/korora";
    korora.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    { nixpkgs, korora, ... }:
    import ./. {
      korora = korora.lib;
      inherit (nixpkgs) lib;
    };
}
