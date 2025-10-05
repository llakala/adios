{ load' }:
{
  load = root: {
    modules = load' root;
    eval = _: { };
  };
}
