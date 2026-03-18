let
  adios = import ./adios;
in
adios // {
  adios = (builtins.warn or builtins.trace) ''
  Adios no longer requires a subattribute to access it via the `default.nix`.
  Before, one would do:

  ```
  { sources }:
  let
    adios = (import sources.adios).adios;
  in
  ```

  Now, you can just do:

  ```
  { sources }:
  let
    adios = import sources.adios;
  in
  ```

  In the future, this will error.
'' adios;
}
