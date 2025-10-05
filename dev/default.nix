{
  __sources ? import ../npins,
  pkgs ? import __sources.nixpkgs { },
  adios' ? import ../. { },
  adios-contrib ? adios'.adios-contrib,
}:

let
  inherit (pkgs) callPackage;
in
{

  treefmt =
    let
      treefmt = adios-contrib.modules.treefmt.apply { inherit pkgs; };
      fmts = treefmt.modules;
    in
    (treefmt {
      projectRootFile = "flake.nix";
      formatters = [
        (fmts.nixfmt {
          package = pkgs.nixfmt-rfc-style;
        })
        (fmts.deadnix {
          package = pkgs.deadnix;
        })
        (fmts.statix {
          package = pkgs.statix;
          inherit pkgs;
        })
      ];
    }).package;

  doc = callPackage ../doc { };

}
