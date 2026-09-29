{
  __functor = _: resolve: {
    __adiosPromise = true;
    inherit resolve;
  };
  map = resolve: {
    __adiosAwaiting = true;
    inherit resolve;
  };
}
