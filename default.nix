rec {
  adios = (builtins.abort or builtins.warn) ''
    The providers-and-consumers branch of my Adios fork has been deprecated.
    Please instead point to the master branch of llakala/adios.
  '' import ./adios;
  adios-contrib = import ./contrib adios;
}
