set -e

# env setup phase
unset PATH
for p in $baseInputs $buildInputs; do
    export PATH=$p/bin:${PATH:+:}$PATH
done

# unpack phase
tar -xf $src

# cd phase
for d in *; do
    if [ -d "$d" ]; then
        cd "$d"
        break
    fi
done

# configure phase
./configure --prefix=$out

# build phase
make

# install phase
make install

# fixup phase
find $out -type f -exec patchelf --shrink-rpath '{}' \; -exec strip '{}' \; 2>/dev/null
