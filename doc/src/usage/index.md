# Usage

## Basic attributes

To understand Adios modules, let's first go over some special attributes of them.

### `impl`

At their core, Adios modules aim to perform some computation. Therefore, this is a perfectly valid module:

```nix
{
  impl = {}: 2 + 5;
}
```

When calling this module (see [the next section](TODO)), the `impl` will be called automatically.

However, just performing some computation isn't very useful if it doesn't take any inputs. For that reason, we also have have...

### `options`

This creates some typed interface for a module. For example:

```nix
{
  options = {
    someNumber = {
      type = adios.types.int;
      default = 0;
      # Optional parameters
      example = 25;
      description = "Your favorite number";
    };
    someString = {
      type = adios.types.string;
      # No default provided - user must supply their own value
    };
  };
}
```

Options can also be computed based on the value of other options, using a `defaultFunc`:

```nix
{
  options = {
    hello = {
      type = adios.types.string;
      default = "hello";
    };
    doubledNumber = {
      type = adios.types.string;
      defaultFunc = { options }: options.hello + " world"; # output: "hello world"
    };
  };
}
```

Options make the most sense in tandem with an `impl`. This module adds together two numbers inputted by the user:

```nix
{
  options = {
    first = {
      type = adios.types.int;
    };
    second = {
      type = adios.types.int;
    };
  };

  impl = { options }: options.first + options.second;
}
```

The `impl` is passed the values for all the options that have been set (including defaults). IN the above codeblock, If
the user didn't set a value for the `first` option, they'd get an error.

```
error:
       ...
       error: attribute 'first' missing
       at /home/demo/Documents/repos/adios/demo.nix:12:31:
           11|
           12|   impl = { options }: options.first + options.second;
             |                               ^
           13| }
```

However, modules aren't very useful if we don't know how to call them. So let's learn how to do that.

## Calling modules

Since modules are just attribute sets, for them to do anything, they have to be loaded by Adios itself. Let's store our
module we just wrote in its own file:

```nix
# module.nix
{ adios }:
{
  options = {
    first = {
      type = adios.types.int;
    };
    second = {
      type = adios.types.int;
    };
  };

  impl = { options }: options.first + options.second;
}
```

The module needs `adios` to define its types, so we include it as a parameter of the file. Now, we'll write a little
`flake.nix` that loads and calls this module:

  ```nix
{
  inputs = {
    adios.url = "github:adisbladis/adios";
  };
  outputs =
    inputs:
    let
      adios = inputs.adios.adios;
      module = import ./module.nix { inherit adios; };
      instantiatedModule = ((adios module).eval {}).root;
    in {
      demo = instantiatedModule { first = 5; second = 2; }; # Outputs 7
    };
}
```

We now have a module that takes

## Module loading

The module definition then needs to be _loaded_ by the adios loader function:
``` nix
adios {
  name = "my-module";
}
```
Module loading is responsible for

- Wrapping the module definition with a type checker

  Module definitions are strictly typed and checked.

- Wrapping of module definitions `impl` function that provides type checking.

### Callable modules

Callable modules are modules with an `impl` function that takes an attrset with their arguments defined in `options`:
``` nix
{{#include callable.nix}}
```

Note that module returns are not type checked.
It is expected to pass the return value of a module into another module until you have a value that can be consumed.

### Laziness

Korora does eager evaluation when type checking values.
Adios module type checking however is lazily, with some caveats:

- Each option, type, test, etc returned by a module are checked on-access

- When calling a module each passed option is checked lazily

But defined `struct`'s, `listOf` etc thunks will be forced.
It's best for options definitions to contain a minimal interface to minimize the overhead of eager evaluation.
