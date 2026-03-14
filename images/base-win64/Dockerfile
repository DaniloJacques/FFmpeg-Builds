ARG GH_REPO=ghcr.io/martineesmaa/ffmpeg-builds
FROM $GH_REPO/base:latest

RUN --mount=src=ct-ng-config,dst=/.config \
    git clone --filter=blob:none https://github.com/crosstool-ng/crosstool-ng.git /ct-ng && cd /ct-ng && \
    ./bootstrap && \
    ./configure --enable-local && \
    make -j$(nproc) && \
    cp /.config .config && \
    ./ct-ng build && \
    cd / && \
    rm -rf ct-ng

# Prepare "cross" environment to heavily favour static builds
RUN \
    find /opt/ct-ng \
        -name "*.dll" \
        -or -name "*.dll.a" \
        -delete && \
    mkdir /opt/ffbuild

# AMD Optimizing C/C++ Compiler (AOCC) 5.1.0 Installation
RUN \
    apt-get -y update && \
    apt-get -y install --no-install-recommends wget wine-stable && \
    wget --referer=https://www.amd.com/en/developer/aocc/eula/aocc-5-1-eula.html \
        https://download.amd.com/developer/eula/aocc/aocc-5-1/aocc-compiler-5.1.0_1_amd64.deb -O /tmp/aocc.deb && \
    apt-get install -y /tmp/aocc.deb && \
    rm /tmp/aocc.deb && \
    # Create symlinks for generic clang invocations to AOCC frontend
    ln -sf /opt/AMD/aocc-compiler-5.1.0/bin/clang /usr/local/bin/clang && \
    ln -sf /opt/AMD/aocc-compiler-5.1.0/bin/clang++ /usr/local/bin/clang++ && \
    ln -sf /opt/AMD/aocc-compiler-5.1.0/bin/flang /usr/local/bin/flang && \
    ln -sf /opt/AMD/aocc-compiler-5.1.0/bin/lld /usr/local/bin/lld && \
    apt-get -y clean autoclean && \
    rm -rf /var/lib/apt/lists/*

ENV FFBUILD_TOOLCHAIN=x86_64-w64-mingw32 \
    FFBUILD_RUST_TARGET=x86_64-pc-windows-gnu

RUN \
    rustup target add "$FFBUILD_RUST_TARGET" && \
    echo "[target.$FFBUILD_RUST_TARGET]\nlinker = \"${FFBUILD_TOOLCHAIN}-gcc\"\nar = \"${FFBUILD_TOOLCHAIN}-gcc-ar\"\n" > "$CARGO_HOME"/config.toml

ADD toolchain.cmake /toolchain.cmake
ADD cross.meson /cross.meson

ENV PATH="/opt/AMD/aocc-compiler-5.1.0/bin:/opt/ct-ng/bin:${PATH}" \
    FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --cross-prefix=${FFBUILD_TOOLCHAIN}- --arch=x86_64 --target-os=mingw32 --enable-lto" \
    FFBUILD_CROSS_PREFIX=${FFBUILD_TOOLCHAIN}- \
    FFBUILD_PREFIX=/opt/ffbuild \
    FFBUILD_DESTDIR=/opt/ffdest \
    FFBUILD_DESTPREFIX=/opt/ffdest/opt/ffbuild \
     FFBUILD_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig \
    CC="clang --target=${FFBUILD_TOOLCHAIN} --sysroot=/opt/ct-ng/${FFBUILD_TOOLCHAIN}/sysroot/mingw" \
    CXX="clang++ --target=${FFBUILD_TOOLCHAIN} --sysroot=/opt/ct-ng/${FFBUILD_TOOLCHAIN}/sysroot/mingw" \
    LD="clang --target=${FFBUILD_TOOLCHAIN} --sysroot=/opt/ct-ng/${FFBUILD_TOOLCHAIN}/sysroot/mingw -fuse-ld=lld" \
    AR="${FFBUILD_TOOLCHAIN}-gcc-ar" \
    RANLIB="${FFBUILD_TOOLCHAIN}-gcc-ranlib" \
    NM="${FFBUILD_TOOLCHAIN}-gcc-nm" \
    DLLTOOL="${FFBUILD_TOOLCHAIN}-dlltool" \
    GENDEF="${FFBUILD_TOOLCHAIN}-gendef" \
    CFLAGS="-static-libgcc -static-libstdc++ -I/opt/ffbuild/include -O2 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CXXFLAGS="-static-libgcc -static-libstdc++ -I/opt/ffbuild/include -O2 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    LDFLAGS="-static-libgcc -static-libstdc++ -L/opt/ffbuild/lib -O2 -pipe -fstack-protector-strong" \
    STAGE_CFLAGS="-fno-semantic-interposition" \
    STAGE_CXXFLAGS="-fno-semantic-interposition"
