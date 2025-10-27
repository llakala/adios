rec {
  adios = import ./adios;
  adios-contrib = import ./contrib { inherit adios; };
}
