{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  # nativeBuildInputs is usually what you want -- tools you need to run
  nativeBuildInputs = [
    # The cacert package is needed by git because this project's CMake config fetches
    # packages from github using https.  See
    # https://github.com/NixOS/nixpkgs/issues/64212#issuecomment-1244404378
    #pkgs.cacert
    #pkgs.git

    pkgs.hugo
    pkgs.go # Require Go so Hugo modules work
  ];
}
