# Motivation

Adios aims to be a radically simple alternative to the NixOS module system that solves many of it's design problems.
Modules are contracts that are typed using the [Korora](https://github.com/adisbladis/korora) type system.

## NixOS module system problems

- Lack of modularity

Ironically the NixOS module system isn't very modular.
If I want to run a web service defined in NixOS, but use a database hosted elsewhere that may not be possible without forking the NixOS module.

The idea is to define higher level interfaces that can be implemented by many different modules.

- Lack of flexibility

NixOS modules aren't reusable outside of a NixOS context.
The goal is to have modules that can be reused just as easily on a MacOS machine as in a Linux development shell.

- Global namespace

The NixOS module system is a single global namespace where any module can affect any other module.

- Resource overhead

Because of how NixOS modules are evaluated, each evaluation has no memoisation from a previous one.
This has the effect of very high memory usage.

Adios modules are designed to take advantage of lazy evaluation and memoisation.
