# Adios - A Nix module system

## Note

This is a fork of Adios, implementing some patches that haven't yet been accepted upstream, such as:

- Modules are now able to call another's `impl` via `inputs.foo {}`
- A module can now call its own `impl` via `options {}`
- An opt-in mutation API has been introduced, which let one module set another module's option via user-defined merge
  semantics

Future changes may be introduced here without an accompanying PR back. This is purely to prevent constant rebasing for
changes that aren't sure to be merged. Upstream developers can request anything to be ported back if they'd like it.

Thank you to adisbladis for his work on Adios.
