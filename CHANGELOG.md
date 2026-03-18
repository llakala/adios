Any new features or breaking changes will be listed here.

# 3/18/2026

- `adios = (import sources.adios).adios` boilerplate is no longer required. Instead, one can just do `adios = import
  sources.adios`. This comes along with the removal of the `contrib/` modules. The old entrypoint now provides a
  warning.

- An opt-in mutation API has been introduced, which let one module set another module's option via user-defined merge
  semantics

- Modules are now able to call another's `impl` via `inputs.foo {}`

- A module can now call its own `impl` via `options {}`
