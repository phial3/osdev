# Arguments
ARG VERSION=24.04

# Basements
FROM ubuntu:$VERSION

# Environments
ENV OPT_APP="/opt/app" \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai   \
    LANG=en_US.UTF-8   \
    LANGUAGE=en_US:en  \
    LC_ALL=en_US.UTF-8 \
    RUBYOPT=-W0

# Use USTC mirrors
##RUN sed -i 's#//.*.ubuntu.com#//mirrors.ustc.edu.cn#g' /etc/apt/sources.list.d/ubuntu.sources

# arm-gnu-toolchain
ARG GCC_AARCH64=https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-aarch64-aarch64-none-elf.tar.xz
ARG GCC_X86_64=https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-elf.tar.xz

ARG BASEMENT_PACKAGES="\
    build-essential \
    ca-certificates \
    openssl \
    openssh-server \
    openssh-client \
    gdb-multiarch \
    tzdata \
    locales \
    net-tools \
    iputils-ping \
    dnsutils \
    lsof \
    nmap \
    telnet \
    tcpdump \
    aptitude \
    apt-utils \
    cmake \
    autoconf \
    automake \
    libtool \
    bison \
    flex \
    gawk \
    gperf \
    git \
    curl \
    wget \
    tree \
    zsh \
    zip \
    unzip \
    file \
    gdb \
    yasm \
    nasm \
    clang \
    llvm \
    ruby \
    ruby-dev \
    texinfo \
    virtualenv \
    ninja-build \
    pkg-config \
    binutils-dev \
    libboost-all-dev \
    libpixman-1-dev \
    libglib2.0-dev \
    libusb-1.0.0-dev \
    libclang-dev \
    libass-dev \
    libfreetype6-dev \
    libsdl2-dev \
    libtheora-dev \
    libva-dev \
    libvdpau-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    zlib1g-dev \
    libopus-dev \
    libvpx-dev \
    libx264-dev \
    libx265-dev \
    libnuma-dev \
    libfdk-aac-dev \
    libmp3lame-dev \
    libvorbis-dev \
    libxvidcore-dev \
    libunistring-dev \
    libaom-dev \
    libgtk-3-dev \
    libavcodec-dev \
    libavformat-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libv4l-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libssl-dev \
    libelf-dev \
    gfortran \
    openexr \
    libatlas-base-dev \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    python3-numpy \
    libtbb-dev \
    libopenexr-dev \
    libhidapi-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libglu1-mesa-dev \
    freeglut3-dev \
    mesa-common-dev \
    "

ARG ADDITIONAL_DEVELOPMENT_PACKAGES="\
    httpie \
    vim \
    nano \
    neovim \
    wrk \
    htop \
    tmux \
    screen \
    rsync \
    # qemu-kvm \
    # virtinst \
    # bridge-utils \
    # libvirt-daemon \
    # libvirt-clients \
    # libvirt-daemon-system \
    "

# Check package availability
RUN apt-get update && \
    apt-get upgrade -y && \
    echo "$BASEMENT_PACKAGES $ADDITIONAL_DEVELOPMENT_PACKAGES" | \
    xargs -n 1 bash -c 'apt-cache show $0 >/dev/null 2>&1 || { echo "Package $0 not found"; exit 1; }'

# Update apt source and install necessary packages
RUN apt-get update \
    && apt-get install --no-install-recommends -y $BASEMENT_PACKAGES $ADDITIONAL_DEVELOPMENT_PACKAGES \
    && apt-get clean -q -y \
    && apt-get autoremove -q -y \
    && apt-get autoclean -q -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /code

# GDB
COPY .gdbinit /root/.gdbinit
COPY auto /root/.gdbinit.d/auto

# rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# arm-gnu-toolchain
RUN if [ "$(uname -m)" = "aarch64" ]; then wget ${GCC_AARCH64}; else wget ${GCC_X86_64}; fi; \
    tar -xJvf arm-gnu-toolchain-13.3*.tar.xz -C ${OPT_APP} \
    rm -rf arm-gnu-toolchain-13.3*.tar.xz

# Ruby
COPY Gemfile .
RUN gem install bundler && \
    bundle config set --local without 'development' && \
    bundle install --retry 3

## Qemu .gitmodules 中的 https://gitlab.com/ 无法访问
RUN git clone --recurse-submodules --depth 1 -b stable-9.1 https://github.com/qemu/qemu.git && \
    cd qemu && \
    ./configure \
    --prefix=${OPT_APP}/qemu \
    --target-list=aarch64-softmmu,aarch64-linux-user,x86_64-softmmu,x86_64-linux-user,riscv64-softmmu,riscv64-linux-user,loongarch64-softmmu,loongarch64-linux-user \
    --enable-modules \
    --enable-tcg-interpreter \
    --enable-debug-tcg       \
    --enable-slirp \
    --enable-linux-user \
    --enable-system \
    --disable-werror \
    --disable-sdl \
    --disable-vnc \
    --disable-gtk \
    --disable-opengl \
    --disable-spice \
    --disable-xen \
    --disable-tools \
    --disable-curses \
    --python=/usr/bin/python3 && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean

# openocd
RUN git clone --recurse-submodules --depth 1 -b master https://github.com/openocd-org/openocd.git && \
    cd openocd && \
    ##git checkout tags/v0.12.0 && \
    ./bootstrap && \
    ./configure \
    --prefix=${OPT_APP}/openocd \
    --enable-sysfsgpio \
    --enable-ftdi \
    --enable-stlink \
    --enable-cmsis-dap && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean

# ffmpeg
RUN git clone --recurse-submodules --depth 1 -b release/7.0 https://github.com/FFmpeg/FFmpeg.git && \
    cd FFmpeg && \
    ./configure \
    --prefix=${OPT_APP}/ffmpeg \
    --enable-gpl \
    --enable-version3 \
    --enable-small \
    --enable-shared \
    --enable-libmp3lame \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libfdk-aac \
    --enable-libass \
    --enable-libfreetype \
    --enable-nonfree \
    --enable-openssl && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean

# opencv
RUN git clone --recurse-submodules --depth 1 -b 4.x https://github.com/opencv/opencv.git && \
    git clone --recurse-submodules --depth 1 -b 4.x https://github.com/opencv/opencv_contrib.git && \
    cd opencv && \
    mkdir build && cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_INSTALL_PREFIX=${OPT_APP}/opencv \
          -D OPENCV_EXTRA_MODULES_PATH=/code/opencv_contrib/modules \
          -D ENABLE_PRECOMPILED_HEADERS=OFF \
          -D BUILD_TESTS=OFF \
          -D BUILD_EXAMPLES=OFF \
          -D WITH_TBB=ON \
          -D WITH_V4L=ON \
          -D WITH_FFMPEG=ON \
          -D BUILD_opencv_python3=ON \
          -D FFMPEG_LIBRARIES=${OPT_APP}/ffmpeg/lib \
          -D FFMPEG_INCLUDE_DIR=${OPT_APP}/ffmpeg/include \
          -D PKG_CONFIG_PATH=${OPT_APP}/ffmpeg/lib/pkgconfig \
          .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean

ENV PATH="$HOME/.cargo/bin:${OPT_APP}/openocd/bin:${OPT_APP}/ffmpeg/bin:${OPT_APP}/opencv/bin:${OPT_APP}/qemu/bin:$PATH"
ENV LD_LIBRARY_PATH="${OPT_APP}/openocd/lib:${OPT_APP}/ffmpeg/lib:${OPT_APP}/opencv/lib:$LD_LIBRARY_PATH"

# Timezone and locale
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# Initialize zinit and nvim plugins
RUN cat ~/.zshrc | sed 's/lucid wait//g;s/zinit light/zinit load/g;s/#.*$//g;/^zinit ice *$/d' > /tmp/zshrc \
    && sed -i '/^$/d' /tmp/zshrc \
    && zsh -c "TERM=xterm source /tmp/zshrc; nvim -c 'q'; rm -rf /tmp/*; exit 0"

RUN chsh -s /bin/zsh
CMD ["/bin/zsh"]