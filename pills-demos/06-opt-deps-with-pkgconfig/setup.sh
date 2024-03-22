# env setup phase
unset PATH
for p in $baseInputs $buildInputs; do
    # amend PATH
    if [ -d $p/bin ]; then
        export PATH=$p/bin:${PATH:+:}$PATH
    fi
    # amend PKG_CONFIG_PATH
    if [ -d $p/lib/pkgconfig ]; then
        export PKG_CONFIG_PATH="$p/lib/pkgconfig${PKG_CONFIG_PATH:+:}$PKG_CONFIG_PATH"
    fi
done

function unpackPhase() {
    tar -xzf $src

    for d in *; do
        if [ -d "$d" ]; then
            cd "$d"
            break
        fi
    done
}

function configurePhase() {
    ./configure --prefix=$out
}

function buildPhase() {
    make
}

function installPhase() {
    make install
}

function fixupPhase() {
    find $out -type f -exec patchelf --shrink-rpath '{}' \; -exec strip '{}' \; 2>/dev/null
}

function genericBuild() {
    unpackPhase
    configurePhase
    buildPhase
    installPhase
    fixupPhase
}
