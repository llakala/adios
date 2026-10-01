let
  inherit (builtins)
    elemAt
    foldl'
    functionArgs
    head
    isAttrs
    length
    zipAttrsWith
    ;

  recurse = zipAttrsWith (
    name: values:
    if length values == 1 then
      # only one side, stop recursing
      head values
    else
      let
        lhs = head values;
        rhs = elemAt values 1;
      in
      if !isAttrs rhs then
        # can't recurse, not awaiting. rhs wins
        rhs
      else if rhs.__adiosAwaiting or false then
        # awaiting a previous value to inject into it
        if (lhs.__adiosPromise or false) then
          # left side is a promise, create a new promise that calls the old one
          {
            __adiosPromise = true;
            # preserve the same functionArgs as the original
            __promiseArgs = lhs.__promiseArgs or (functionArgs lhs.resolve);
            resolve = args: rhs.resolve (lhs.resolve args);
          }
        else
          # left side wasn't a promise, pass the prev value directly
          rhs.resolve lhs
      else if !isAttrs lhs then
        # left isn't an attrset, rhs wins
        rhs
      else
        # lhs and rhs are both non-promise attrsets
        recurse [ lhs rhs ]
  );
in
foldl' (
  a: b:
  if a == {} then
    b
  else
    recurse [ a b ]
) {}
