{ pkgs, lib, config, inputs, ... }:

{
  env = {
    GREET = "devenv";
    RUSTC_WRAPPER = "sccache";
  };

  packages = with pkgs; [
    git
    sccache
  ];

  languages.rust = {
    enable = true;
    channel = "stable";
    components = [
      "rustc"
      "cargo"
      "clippy"
      "rustfmt"
      "rust-analyzer"
      "rust-src"
    ];
  };
}
