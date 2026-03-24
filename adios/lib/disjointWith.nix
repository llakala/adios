{ printList }:
let
  inherit (builtins) all;
in
disjointNames:
{ options }:
if all (name: !options ? ${name}) disjointNames then
  true
else
  let
    inherit (builtins) filter head length;
    foundNames = filter (name: options ? ${name}) disjointNames;
  in
  if length disjointNames == 1 || length foundNames == 1 then
    "option is disjoint with '${head foundNames}'. only one of these should be set at a time"
  else
    "option is disjoint with options '${printList foundNames}', which were also set"
