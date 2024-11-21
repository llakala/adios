{
  description = "Adios";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };
  outputs = { nixpkgs }: import ./. { inherit (nixpkgs) lib; };
}
