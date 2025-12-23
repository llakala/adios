{
  # Use the API we created before.
  #
  # If a module doesn't specify anything under the "special" attributes
  # (options, config, etc), then it'll be treated as if it's all under `config`,
  # and is just mutating the state of other modules.
  programs.hello = {
    # Since we DON'T specify an alternative package here, the value of the
    # `.package` option falls back to its default (`pkgs.hello`)
    enable = true;
  };
}
