## Issues with the NixOS module system

To understand why Adios exists, and what it does differently, we should first look at how the NixOS module system works.
Here's an annotated module, that creates a custom API for working with the `hello` package:

```nix
{{#include nixos/helloModule.nix}}
```

Now, here's another module that actually uses that API we created:

```nix
{{#include nixos/setsHello.nix}}
```

Now that we have some understanding of how NixOS modules work, we can look at the problems it has.

### Global namespace

We were able to mutate the state of `environment.systemPackages` and our custom `programs.hello` modules without
actually declaring a dependency on those modules - we just assumed that the options existed. This is convenient, but it
has a key issue when it comes to performance - **even if we still don't use a module, it must be evaluated**.

To understand why this is, let's imagine evaluating this module:
```nix
{{#include nixos/setsNonexistantOption.nix}}
```

This option we're setting _might_ exist - but we can't know that it exists unless we evaluate every single module we
were given to check for it. This has made NixOS evaluation time get much slower over the years, as more modules have
been added - see the relevant [issue](TODO LINK) in nixpkgs.

### Lack of flexibility

TODO: get help from adis on rewriting this

NixOS modules aren't reusable outside of a NixOS context.
The goal is to have modules that can be reused just as easily on a MacOS machine as in a Linux development shell.

### Resource overhead

TODO: get help from adis on rewriting this

Because of how NixOS modules are evaluated, each evaluation has no memoisation from a previous one.
This has the effect of very high memory usage.

Adios modules are designed to take advantage of lazy evaluation and memoisation.
