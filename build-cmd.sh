#!/bin/bash

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

EXPAT_VERSION=2.1.0
EXPAT_SOURCE_DIR=expat-$EXPAT_VERSION

top="$(dirname "$0")"
stage="$(pwd)"

echo "${EXPAT_VERSION}" > "${stage}/VERSION.txt"

pushd "$top/$EXPAT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            set +x
            load_vsvars
            set -x

            cmake -G"Visual Studio 12" . -DBUILD_shared:BOOL=OFF

            build_sln "expat.sln" "Debug|Win32" "expat" || exit 1
            build_sln "expat.sln" "Release|Win32"  "expat" || exit 1

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp Release/expat.lib "$stage/lib/release/"
            cp Debug/expat.lib "$stage/lib/debug/"
            
            INCLUDE_DIR="$stage/include/expat"
            mkdir -p "$INCLUDE_DIR"
            cp lib/expat.h "$INCLUDE_DIR"
            cp lib/expat_external.h "$INCLUDE_DIR"
        ;;
        "windows64")
            set +x
            load_vsvars
            set -x

            cmake -G"Visual Studio 12 Win64" . -DBUILD_shared:BOOL=OFF

            build_sln "expat.sln" "Debug|x64" "expat" || exit 1
            build_sln "expat.sln" "Release|x64"  "expat" || exit 1

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp Release/expat.lib "$stage/lib/release/"
            cp Debug/expat.lib "$stage/lib/debug/"
            
            INCLUDE_DIR="$stage/include/expat"
            mkdir -p "$INCLUDE_DIR"
            cp lib/expat.h "$INCLUDE_DIR"
            cp lib/expat_external.h "$INCLUDE_DIR"
        ;;
        'darwin')
            DEVELOPER=$(xcode-select --print-path)
            opts="-arch i386 -arch x86_64 -iwithsysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk -mmacosx-version-min=10.7"
            export CFLAGS="$opts"
            export CXXFLAGS="$opts"
            export LDFLAGS="$opts"
            export CC="llvm-gcc"
            export PREFIX="$stage"
            ./configure --prefix=$PREFIX
            make
            make install
            
            mv "$PREFIX/lib" "$PREFIX/release"
            mkdir -p "$PREFIX/lib"
            mv "$PREFIX/release" "$PREFIX/lib"
            pushd "$PREFIX/lib/release"
            fix_dylib_id "libexpat.dylib"
            popd
            
            mv "$PREFIX/include" "$PREFIX/expat"
            mkdir -p "$PREFIX/include"
            mv "$PREFIX/expat" "$PREFIX/include"
        ;;
        'linux')
            PREFIX="$stage"
            CFLAGS="-m32 -O3" ./configure --prefix="$PREFIX" --includedir="$PREFIX/include/expat" --libdir="$PREFIX/lib/release"
            make
            make install

            make distclean

            CFLAGS="-m32 -Og -g" ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib/debug"
            make
            make install
        ;;
        'linux64')
            CFLAGS="-m64 -Og -g -fPIC -DPIC" ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug" --includedir="\${prefix}/include/expat"
            make
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make distclean

            CFLAGS="-m64 -O3 -fPIC -DPIC" ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release" --includedir="\${prefix}/include/expat" 
            make
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make distclean

        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp "COPYING" "$stage/LICENSES/expat.txt"
popd

pass

