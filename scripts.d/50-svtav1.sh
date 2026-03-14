#!/bin/bash

SCRIPT_REPO="https://gitlab.com/AOMediaCodec/SVT-AV1.git"
SCRIPT_COMMIT="4ae9272b588a05ee6e77a43e8dfdac05f54c4ff0"

ffbuild_enabled() {
    [[ $TARGET == win32 ]] && return -1
    (( $(ffbuild_ffver) > 700 )) || return -1
    return 0
}

ffbuild_dockerdl() {
    echo "git clone \"$SCRIPT_REPO\" . && git checkout \"$SCRIPT_COMMIT\""
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    cp "$FFBUILD_CMAKE_TOOLCHAIN" "$PWD/clang_toolchain.cmake"
    echo 'set(CMAKE_C_COMPILER clang)' >> "$PWD/clang_toolchain.cmake"
    echo 'set(CMAKE_CXX_COMPILER clang++)' >> "$PWD/clang_toolchain.cmake"
    echo 'set(CMAKE_AR llvm-ar)' >> "$PWD/clang_toolchain.cmake"
    echo 'set(CMAKE_RANLIB llvm-ranlib)' >> "$PWD/clang_toolchain.cmake"
    echo 'set(CMAKE_NM llvm-nm)' >> "$PWD/clang_toolchain.cmake"

    # Build clean CFLAGS for Clang based on RAW_CFLAGS, stripping incompatible flags
    local CLEAN_CFLAGS="${RAW_CFLAGS//-static-libgcc/}"
    CLEAN_CFLAGS="${CLEAN_CFLAGS//-static-libstdc++/}"
    local CLEAN_CXXFLAGS="${RAW_CXXFLAGS//-static-libgcc/}"
    CLEAN_CXXFLAGS="${CLEAN_CXXFLAGS//-static-libstdc++/}"
    local CLEAN_LDFLAGS="${RAW_LDFLAGS//-static-libgcc/}"
    CLEAN_LDFLAGS="${CLEAN_LDFLAGS//-static-libstdc++/}"

    local CLANG_CFLAGS="$CLEAN_CFLAGS $FF_CFLAGS --target=$FFBUILD_TOOLCHAIN -Wno-unused-command-line-argument"
    local CLANG_CXXFLAGS="$CLEAN_CXXFLAGS $FF_CXXFLAGS --target=$FFBUILD_TOOLCHAIN -Wno-unused-command-line-argument"
    local CLANG_LDFLAGS="$CLEAN_LDFLAGS --target=$FFBUILD_TOOLCHAIN --gcc-toolchain=/opt/ct-ng -fuse-ld=lld"

    if [[ $TARGET == win* ]]; then
        # Override sysroot for MinGW and add GCC libgcc path
        local GCC_LIB_DIR="$(dirname $(${FFBUILD_TOOLCHAIN}-gcc -print-libgcc-file-name))"
        echo "set(CMAKE_SYSROOT /opt/ct-ng/${FFBUILD_TOOLCHAIN}/sysroot/mingw)" >> "$PWD/clang_toolchain.cmake"
        CLANG_CFLAGS="$CLANG_CFLAGS --sysroot=/opt/ct-ng/$FFBUILD_TOOLCHAIN/sysroot/mingw -Qunused-arguments"
        CLANG_CXXFLAGS="$CLANG_CFLAGS"
        CLANG_LDFLAGS="$CLANG_LDFLAGS --sysroot=/opt/ct-ng/$FFBUILD_TOOLCHAIN/sysroot/mingw -L$GCC_LIB_DIR -L/opt/ct-ng/$FFBUILD_TOOLCHAIN/sysroot/lib"
    else
        CLANG_CFLAGS="$CLANG_CFLAGS --gcc-toolchain=/opt/ct-ng"
        CLANG_CXXFLAGS="$CLANG_CXXFLAGS --gcc-toolchain=/opt/ct-ng"
    fi

    export CFLAGS="$CLANG_CFLAGS"
    export CXXFLAGS="$CLANG_CXXFLAGS"
    export LDFLAGS="$CLANG_LDFLAGS"

    cmake -DCMAKE_TOOLCHAIN_FILE="$PWD/clang_toolchain.cmake" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX" \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_APPS=OFF -DENABLE_AVX512=ON -DSVT_AV1_LTO=OFF ..
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}

ffbuild_configure() {
    echo --enable-libsvtav1
}

ffbuild_unconfigure() {
    (( $(ffbuild_ffver) >= 404 )) || return 0
    echo --disable-libsvtav1
}
