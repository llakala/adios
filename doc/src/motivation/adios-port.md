## Porting the module to Adios

### A direct port

Adios modules are designed to take full advantage of lazy evaluation and memoisation. To understand why, we'll write an
direct port of the `hello` module we wrote before.

```nix
{{#include adios/hello/original.nix}}
```

This time, instead of having the package installed on our system, we'll just be installing the package into a
devshell, for reasons we'll get into later.

```nix
{{#include adios/flake/original.nix}}
```

We now have an equivalent module, but we'd like to change it a bit, to match Adios best practices.

### We don't need an `enable` option anymore

With Adios, things are only evaluated when they're actually used. Because of this, we can get rid of the `enable`
option.

```nix
{{#include adios/hello/noEnableOption.nix}}
```

```nix
{{#include adios/flake/noEnableOption.nix}}
```

### We want to define multiple modules

Right now, we're _only_ calling Adios on the hello module. But we want to write other modules in the future, and then
use a subset of them. To do this, we can create a "root" module that contains pointers to other modules, like this:

```nix
{{#include adios/flake/usingRootModule.nix}}
```

### We want to inject `pkgs` more intelligently

Currently, we're passing `pkgs` to the hello module manually. But what if we could instead read from another module to
get access to it?

```nix
{{#include adios/nixpkgs.nix}}
```

```nix
{{#include adios/hello/final.nix}}
```

You might ask - how are we going to set the value of `pkgs`? We need to inject the value of an option from OUTSIDE the
modules. Well, Adios actually provides the ability to do that!


```nix
{{#include adios/flake/injectingNixpkgs.nix}}
```

### We can give the job of importing the modules to a helper function

Adios provides a function called `importModules` (documented [here](TODO LINK)). Now that each of our modules only
depends on adios, we can use this to autocall the modules in the `modules/` folder.

```nix
{{#include adios/flake/usingImportModules.nix}}
```

### We can now add other modules, which won't be evaluated if we don't use them

Let's say we have these modules defined in a shared repo, and someone else added a `cowsay` module that we don't use.

```nix
{{#include adios/cowsay.nix}}
```

Adios will never evaluate this module. Even though we necessarily evaluate the nixpkgs module to inject it all over the
tree, that doesn't require forcing the eval of the _consumers_ of the nixpkgs module. This means adding more modules
doesn't provide any performance penalty - a big issue with the nixpkgs module system.

### The final version of our modules

```nix
{{#include adios/flake/final.nix}}
```

```nix
{{#include adios/hello/final.nix}}
```
