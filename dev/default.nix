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
      tree = adios adios-contrib.modules.treefmt;

      # Apply options to tree
      eval = tree.eval {
        options = {
          "/" = {
            inherit pkgs;
          };
        };
      };

      # Call treefmt contracts with applied pkgs
      treefmt = eval.tree;
      fmts = treefmt.modules;
    in
    (treefmt {
      projectRootFile = "flake.nix";
      formatters = [
        (fmts.nixfmt { })
        (fmts.deadnix { })
        (fmts.statix { })
      ];
    }).package;

  doc = callPackage ../doc { };

}
