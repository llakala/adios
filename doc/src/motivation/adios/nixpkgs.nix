# modules/nixpkgs.nix
{ adios }:

{
  options = {
    pkgs = {
      type = adios.types.attrs;
    };
  };
}
