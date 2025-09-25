{
  __sources ? import ../npins,
  pkgs ? import __sources.nixpkgs { },
  adios' ? import ../. { },
  adios ? adios'.adios,
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
        (fmts.nixfmt { })
        (fmts.deadnix { })
        (fmts.statix { })
      ];
    }).package;

  inherit (adios) tests;

  doc = callPackage ../doc { };

}
