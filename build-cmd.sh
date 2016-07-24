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

EXPAT_VERSION=2.2.0
EXPAT_SOURCE_DIR=expat

top="$(dirname "$0")"
stage="$(pwd)"

echo "${EXPAT_VERSION}" > "${stage}/VERSION.txt"

pushd "$top/$EXPAT_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            set +x
            load_vsvars
            set -x

            cmake -G"Visual Studio 14" . -DCMAKE_SYSTEM_VERSION="10.0.10586.0" -DBUILD_shared:BOOL=OFF

            build_sln "expat.sln" "Debug" "Win32" "expat"
            build_sln "expat.sln" "Release" "Win32"  "expat"

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

            cmake -G"Visual Studio 14 Win64" . -DCMAKE_SYSTEM_VERSION="10.0.10586.0" -DBUILD_shared:BOOL=OFF

            build_sln "expat.sln" "Debug" "x64" "expat"
            build_sln "expat.sln" "Release" "x64"  "expat"

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
            opts="-arch i386 -arch x86_64 -iwithsysroot ${DEVELOPER}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk -mmacosx-version-min=10.8"
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
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            CFLAGS="$opts -Og -g -fPIC -DPIC" \
            CXXFLAGS="$opts -Og -g -fPIC -DPIC" \
            ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug" --includedir="\${prefix}/include/expat"
            make -j$JOBS
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check -j$JOBS
            fi

            make distclean

            CFLAGS="$opts -O3 -g $HARDENED -fPIC -DPIC" \
            CXXFLAGS="$opts -O3 -g $HARDENED -fPIC -DPIC" \
            ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release" --includedir="\${prefix}/include/expat" 
            make -j$JOBS
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check -j$JOBS
            fi

            make distclean
        ;;
        'linux64')
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m64}"
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            CFLAGS="$opts -Og -g -fPIC -DPIC" \
            CXXFLAGS="$opts -Og -g -fPIC -DPIC" \
            ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug" --includedir="\${prefix}/include/expat"
            make -j$JOBS
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check -j$JOBS
            fi

            make distclean

            CFLAGS="$opts -O3 -g $HARDENED -fPIC -DPIC" \
            CXXFLAGS="$opts -O3 -g $HARDENED -fPIC -DPIC" \
            ./configure --with-pic --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release" --includedir="\${prefix}/include/expat" 
            make -j$JOBS
            make install DESTDIR="$stage"

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check -j$JOBS
            fi

            make distclean
        ;;
    esac

    mkdir -p "$stage/LICENSES"
    cp "COPYING" "$stage/LICENSES/expat.txt"
popd

pass

