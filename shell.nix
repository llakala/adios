{
  pkgs ? import __sources.nixpkgs { },
  __sources ? import ./npins,
}:

let
  inherit (pkgs) lib;
  # generates docs for korora
  gendocs = pkgs.writeShellScriptBin "gendocs" ''
    ${lib.getExe' pkgs.nixdoc "nixdoc"} --category types --prefix "" --description "Kororā" --file korora/default.nix | sed s/' {#.*'/""/ > korora/README.md
  '';
in

pkgs.mkShell {
  packages = [
    pkgs.npins
    pkgs.mdbook
    pkgs.mdbook-cmdrun

    pkgs.nix-unit
    pkgs.nixdoc
    gendocs
  ];
}
