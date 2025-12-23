# modules/cowsay.nix
{ adios }:
{
  inputs = {
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    package = {
      type = adios.types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.cowsay;
    };
  };

  impl = { options }: options.package;
}
