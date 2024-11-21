{ self, types }:

{
  name = "adios-contrib";

  options = {
    pkgs.type = types.attrs;
  };

  modules = {
    nixos = import ./modules/nixos.nix;
    treefmt = import ./modules/treefmt {
      pkgs' = self.defaults.pkgs;
    };
  };
}
