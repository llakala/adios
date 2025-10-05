{
  __sources ? import ../npins,
  pkgs ? import __sources.nixpkgs { },
  adios' ? import ../. { },
  adios-contrib ? adios'.adios-contrib,
}:

let
  inherit (pkgs) callPackage;
  inherit (adios') adios;
in
{

  treefmt =
    let
      # Load a module definition tree.
      # This type checks modules and provides the tree API.
      tree = adios.lib.load adios-contrib.modules.treefmt;

      treefmt = tree.root;
      fmts = treefmt.modules;
    in
    (treefmt {
      projectRootFile = "flake.nix";
      inherit pkgs;
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
