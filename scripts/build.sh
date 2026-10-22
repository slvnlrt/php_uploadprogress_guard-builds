#!/bin/bash
# Compile une branche du module dans une image Docker officielle.
# Usage : build.sh <X.Y> <tag d'image php> <dossier src du dépôt amont> <dossier de sortie>
# Exemple : build.sh 7.4 7.4-cli-buster ~/php_uploadprogress_guard/src ./bin
#
# Choisir l'image Debian la plus ancienne qui porte la branche (voir README) : une image
# récente (glibc 2.38+) produit un .so qui ne se charge pas sur les systèmes plus anciens.
set -euo pipefail

v=$1
img=$2
src=$(realpath "$3")
out=$(realpath "$4")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cp "$src/config.m4" "$src/hp_uploadprogress_guard.c" "$work/"
cp "$src/rfc1867/rfc1867_copy-$v.c" "$work/rfc1867_copy.c"

docker run --rm -v "$work":/src:ro -v "$out":/out "php:$img" bash -c '
    set -e
    cp -r /src /build && cd /build
    phpize >/tmp/phpize.log 2>&1
    ./configure >/tmp/configure.log 2>&1
    make >/tmp/make.log 2>&1 || { tail -40 /tmp/make.log; exit 1; }
    vv=$(php -r "echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;")
    [ "$vv" = "'"$v"'" ] || { echo "branche inattendue : $vv"; exit 1; }
    echo "compilé avec PHP $(php -r "echo PHP_VERSION;"), $(gcc --version | head -1), $(ldd --version | head -1)"
    cp modules/hp_uploadprogress_guard.so "/out/hp_uploadprogress_guard-$vv.so"
'

# Contrôle de la glibc requise : rien au-delà de GLIBC_2.14.
max=$(objdump -T "$out/hp_uploadprogress_guard-$v.so" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)
echo "glibc maximale requise : $max"
if [ "$(printf '%s\n' "$max" GLIBC_2.14 | sort -V | tail -1)" != GLIBC_2.14 ]; then
    echo "ÉCHEC : $max dépasse GLIBC_2.14, recompiler sur une image plus ancienne" >&2
    exit 1
fi
