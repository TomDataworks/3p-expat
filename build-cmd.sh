#!/bin/sh

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

EXPAT_VERSION=2.0.1
EXPAT_SOURCE_DIR=expat-$EXPAT_VERSION

top="$(dirname "$0")"
STAGING_DIR="$(pwd)"

pushd "$top/$EXPAT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
        	set +x
			load_vsvars
			set -x

			build_sln "expat.sln" "Debug|Win32" "expat_static" || exit 1
            build_sln "expat.sln" "Release|Win32"  "expat_static" || exit 1

			BASE_DIR="$STAGING_DIR/"
            mkdir -p "$BASE_DIR/lib/debug"
            mkdir -p "$BASE_DIR/lib/release"
            cp win32/bin/Release/libexpatMT.lib "$BASE_DIR/lib/release/"
            cp win32/bin/Debug/libexpatMT.lib "$BASE_DIR/lib/debug/"
			
			INCLUDE_DIR="$STAGING_DIR/include/expat"
			mkdir -p "$INCLUDE_DIR"
			cp lib/expat.h "$INCLUDE_DIR"
			cp lib/expat_external.h "$INCLUDE_DIR"
        ;;
        'darwin')
            PREFIX="$STAGING_DIR"
            CC="gcc-4.2" CFLAGS="-arch i386 -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5" \
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
            PREFIX="$STAGING_DIR"
            CFLAGS="-m32" CC="gcc-4.1" ./configure --prefix="$PREFIX"
            make
            make install
            
            mv "$PREFIX/lib" "$PREFIX/release"
            mkdir -p "$PREFIX/lib/"
            mv "$PREFIX/release" "$PREFIX/lib/"
            
            mv "$PREFIX/include" "$PREFIX/expat"
            mkdir -p "$PREFIX/include"
            mv "$PREFIX/expat" "$PREFIX/include"
        ;;
    esac

    mkdir -p "$STAGING_DIR/LICENSES"
    cp "COPYING" "$STAGING_DIR/LICENSES/expat.txt"
popd

pass

