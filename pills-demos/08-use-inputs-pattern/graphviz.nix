{ mkDerivation, lib, gdSupport ? true, gd, pkg-config }:

mkDerivation {
    name = "graphviz";
    src = ../graphviz-2.49.3.tar.gz;

    # add support for png output:
    buildInputs = if gdSupport then [
        pkg-config
        (lib.getLib gd)
        (lib.getDev gd)
    ] else [];

}
