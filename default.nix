{
  lib,
  korora ? import (import ./npins).korora { inherit lib; },
}:
let
  self = {
    adios = import ./adios { inherit korora lib; };
    adios-contrib = self.adios (import ./contrib);
  };
in
self
