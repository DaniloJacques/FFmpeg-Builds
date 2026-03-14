ARG GH_REPO=ghcr.io/martineesmaa/ffmpeg-builds
ARG TAG=latest
FROM $GH_REPO/base:$TAG

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
    find /opt/ct-ng -type l \
        -and -name '*.so' \
        -and -not -ipath '*plugin*' \
        -and -not -name 'libdl.*' \
        -and -not -name 'libc.*' \
        -and -not -name 'libm.*' \
        -and -not -name 'libmvec.*' \
        -and -not -name 'librt.*' \
        -and -not -name 'libpthread.*' \
        -delete && \
    find /opt/ct-ng \
        -name 'libdl.a' \
        -or -name 'libc.a' \
        -or -name 'libm.a' \
        -or -name 'libmvec.a' \
        -or -name 'librt.a' \
        -or -name 'libpthread.a' \
        -delete && \
    mkdir /opt/ffbuild

# LLVM 21 (Rolling Release) Installation for Full Clang Environment
RUN \
    apt-get -y update && \
    apt-get -y install --no-install-recommends curl gnupg lsb-release && \
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/apt.llvm.org.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/apt.llvm.org.gpg] http://apt.llvm.org/noble/ llvm-toolchain-noble-21 main" > /etc/apt/sources.list.d/llvm-toolchain-21.list && \
    apt-get -y update && \
    apt-get -y install --no-install-recommends clang-21 lld-21 llvm-21 && \
    ln -sf /usr/bin/clang-21 /usr/local/bin/clang && \
    ln -sf /usr/bin/clang++-21 /usr/local/bin/clang++ && \
    ln -sf /usr/bin/lld-21 /usr/local/bin/lld && \
    apt-get -y clean autoclean && \
    rm -rf /var/lib/apt/lists/*

ENV FFBUILD_TOOLCHAIN=x86_64-ffbuild-linux-gnu \
    FFBUILD_RUST_TARGET="x86_64-unknown-linux-gnu"

RUN \
    rustup default nightly && \
    echo "[unstable]\ntarget-applies-to-host = true\nhost-config = true\n" > "$CARGO_HOME"/config.toml && \
    echo "[target.$FFBUILD_RUST_TARGET]\nlinker = \"${FFBUILD_TOOLCHAIN}-gcc\"\nar = \"${FFBUILD_TOOLCHAIN}-gcc-ar\"\n" >> "$CARGO_HOME"/config.toml && \
    echo "[target.host]\nlinker = \"gcc\"\nar = \"ar\"\n" >> "$CARGO_HOME"/config.toml

ADD toolchain.cmake /toolchain.cmake
ADD cross.meson /cross.meson

ADD gen-implib.sh /usr/bin/gen-implib
RUN git clone --filter=blob:none --depth=1 https://github.com/yugr/Implib.so /opt/implib

ENV PATH="/opt/ct-ng/bin:${PATH}" \
    FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --cross-prefix=${FFBUILD_TOOLCHAIN}- --arch=x86_64 --target-os=linux --enable-lto" \
    FFBUILD_CROSS_PREFIX="${FFBUILD_TOOLCHAIN}-" \
    FFBUILD_PREFIX=/opt/ffbuild \
    FFBUILD_DESTDIR=/opt/ffdest \
    FFBUILD_DESTPREFIX=/opt/ffdest/opt/ffbuild \
    FFBUILD_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig \
    CC="clang --target=${FFBUILD_TOOLCHAIN} --gcc-toolchain=/opt/ct-ng" \
    CXX="clang++ --target=${FFBUILD_TOOLCHAIN} --gcc-toolchain=/opt/ct-ng" \
    LD="clang --target=${FFBUILD_TOOLCHAIN} --gcc-toolchain=/opt/ct-ng -fuse-ld=lld" \
    AR="${FFBUILD_TOOLCHAIN}-gcc-ar" \
    RANLIB="${FFBUILD_TOOLCHAIN}-gcc-ranlib" \
    NM="${FFBUILD_TOOLCHAIN}-gcc-nm" \
    CFLAGS="-static-libgcc -static-libstdc++ -I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread" \
    CXXFLAGS="-static-libgcc -static-libstdc++ -I/opt/ffbuild/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread" \
    LDFLAGS="-static-libgcc -static-libstdc++ -L/opt/ffbuild/lib -O2 -pipe -fstack-protector-strong -fstack-clash-protection -Wl,-z,relro,-z,now -pthread -lm" \
    STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition" \
    STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
