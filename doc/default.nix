{
  stdenvNoCC,
  __src ? ../.,
  mdbook,
}:

stdenvNoCC.mkDerivation {
  pname = "adios-nix-docs-html";
  version = "0.1";
  src = __src;
  nativeBuildInputs = [
    mdbook
  ];

  dontConfigure = true;
  dontFixup = true;

  env.RUST_BACKTRACE = 1;

  buildPhase = ''
    runHook preBuild
    cd doc
    mdbook build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mv book $out
    runHook postInstall
  '';
}
