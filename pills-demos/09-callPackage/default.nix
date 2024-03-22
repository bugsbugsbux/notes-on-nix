# nix-build                     # or
# nix-build default.nix         # or
# nix-build -A hello            # or
# nix-build -A graphviz         # or
# nix-build -A graphvizCore

let nixpkgs = import <nixpkgs> {};

    allPkgs = nixpkgs // pkgs;

    # Expects path to contain a function, takes its arguments, gets the packages
    # with their names from allPkgs, merges overrides into it, and finalls uses
    # this set as argument to call the function.
    callPackage = path: overrides:
        let f = import path;
        in f ((builtins.intersectAttrs (builtins.functionArgs f) allPkgs) // overrides)
    ;

    pkgs = with nixpkgs; {
        mkDerivation = import ./autotools.nix nixpkgs;
        hello = callPackage ./hello.nix {};
        graphviz = callPackage ./graphviz.nix {};
        graphvizCore = callPackage ./graphviz.nix { gdSupport = false; };
    };

in pkgs
