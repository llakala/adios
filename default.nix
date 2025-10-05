{
  korora ? import (import ./npins).korora { },
}:
let
  self = rec {
    adios = import ./adios { inherit korora; };
    adios-contrib = self.adios (import ./contrib { inherit adios; });
  };
in
self
