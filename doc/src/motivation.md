# Motivation

Adios aims to be a radically simple alternative to the NixOS module system that solves many of it's design problems.
Modules are contracts that are typed using the [Korora](https://github.com/adisbladis/korora) type system.

## NixOS module system problems

- Lack of flexibility

NixOS modules aren't reusable outside of a NixOS context.
The goal is to have modules that can be reused just as easily on a MacOS machine as in a Linux development shell.

- Global namespace

The NixOS module system is a single global namespace where any module can affect any other module.

- Resource overhead

Because of how NixOS modules are evaluated, each evaluation has no memoisation from a previous one.
This has the effect of very high memory usage.

Adios modules are designed to take advantage of lazy evaluation and memoisation.
