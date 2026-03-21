Any new features or breaking changes will be listed here.

# 3/21/2026

- Basic submodule support is now fixed. This originates back to the original commit of adios - and it's so old and
  unused that I didn't understand it until I looked at the old tests. But Adios actually supports "sub-options":
  ```nix
  { types, ... }:
  {
    options.foo = {
      options.bar = {
        type = types.string;
        default = "demo";
      };
    };

    impl = { options }: options.foo.bar;
  }
  ```
  For most cases, I recommend sticking with structs over sub-options. However, a module providing a complex API
  underneath some attribute may benefit from this. Submodule support is something I hope to improve in the future, so
  an option can point to the full API of some input module.

- `types.str`, an alias for `types.string`, has been removed. I don't think this is a necessary alias, and I'd prefer to
  see everyone congregate on the string form.

# 3/19/2026

- The internal path of korora (the Adios type system) has been changed. Uses of `${sources.adios}/types/types.nix`
  should be changed to `${sources.adios}/korora`. This is very unlikely to affect you, unless you're vendoring korora
  specifically from Adios.

- The value of `unknown` for structs now defaults to false. This means that structs will reject any field that they
  don't specify. To achieve the old behavior, the struct can be overridden:
  ```nix
  (types.struct "structName" {
    foo = types.int;
    bar = types.string;
  }).override { unknown = true; }
  ```

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
