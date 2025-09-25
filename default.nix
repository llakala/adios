{
  korora ? import (import ./npins).korora { },
}:
let
  self = {
    adios = import ./adios { inherit korora; };
    adios-contrib = self.adios (import ./contrib);
  };
in
self
