{ types }:
{
  name = "callable-module";

  options = {
    foo = {
      type = types.string;
      default = "foo";
    };
  };

  impl = args: {
    # Evaluating someValue.bar will type check args.foo
    someValue.bar = args.foo;
  };
}
