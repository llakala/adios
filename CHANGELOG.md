Any new features or breaking changes will be listed here.

# 3/18/2026
- The `name` parameter of Adios modules now does absolutely nothing. Originally, names actually had a semantic meaning.
  This has been removed for a long time, but names still slightly improved the state of error logging. Now, they do
  nothing, and won't be included at all when loading a module.

- `(adios root {}).override` has been removed. I've never seen anyone actually use this, and I'm generally unsure about
  some of the design decisions of the eval stage.

- `adios = (import sources.adios).adios` boilerplate is no longer required. Instead, one can just do `adios = import
  sources.adios`. This comes along with the removal of the `contrib/` modules. The old entrypoint now provides a
  warning.

- An opt-in mutation API has been introduced, which let one module set another module's option via user-defined merge
  semantics

- Modules are now able to call another's `impl` via `inputs.foo {}`

- A module can now call its own `impl` via `options {}`
