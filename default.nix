{
  korora ? import (import ./npins).korora { },
}:
let
  self = rec {
    adios = import ./adios { inherit korora; };
    adios-contrib = import ./contrib { inherit adios; };
  };
in
self
