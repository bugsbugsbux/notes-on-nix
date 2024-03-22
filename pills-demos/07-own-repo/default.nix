# nix-build                     # or
# nix-build default.nix         # or
# nix-build -A hello            # or
# nix-build -A graphviz

{
    hello = import ./hello.nix;
    graphviz = import ./graphviz.nix;
}
