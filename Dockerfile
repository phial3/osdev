# Arguments
ARG VERSION=24.04

# Basements
FROM ubuntu:$VERSION

# Environments
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV LANG=en_US.utf8
ENV OPT_APP="/opt/app"

# Use USTC mirrors
RUN sed -i 's#//.*.ubuntu.com#//mirrors.ustc.edu.cn#g' /etc/apt/sources.list.d/ubuntu.sources

ARG BASEMENT_PACKAGES="\
    build-essential \
    ca-certificates \
    openssl \
    openssh-server \
    openssh-client \
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
    cmake \
    autoconf \
    automake \
    libtool \
    git \
    curl \
    wget \
    tree \
    zsh \
    zip \
    unzip \
    file \
    yasm \
    nasm \
    pkg-config \
    texinfo \
    clang \
    llvm \
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
    libswscale-dev \
    libv4l-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libssl-dev \
    gfortran \
    openexr \
    libatlas-base-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-numpy \
    libtbb-dev \
    libopenexr-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libswresample-dev \
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
    "

# Check package availability
RUN apt-get update && \
    echo "$BASEMENT_PACKAGES $ADDITIONAL_DEVELOPMENT_PACKAGES" | \
    xargs -n 1 bash -c 'apt-cache show $0 >/dev/null 2>&1 || { echo "Package $0 not found"; exit 1; }'

# Update apt source and install necessary packages
RUN apt-get update \
    && apt-get install -y $BASEMENT_PACKAGES $ADDITIONAL_DEVELOPMENT_PACKAGES \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# rust
WORKDIR /src
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# ffmpeg
WORKDIR /src
RUN git clone --recurse-submodules --depth 1 -b release/7.0 https://ghp.ci/https://github.com/FFmpeg/FFmpeg.git && \
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
WORKDIR /src
RUN git clone --recurse-submodules --depth 1 -b 4.x https://ghp.ci/https://github.com/opencv/opencv.git && \
    git clone --recurse-submodules --depth 1 -b 4.x https://ghp.ci/https://github.com/opencv/opencv_contrib.git && \
    cd opencv && \
    mkdir build && cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_INSTALL_PREFIX=${OPT_APP}/opencv \
          -D OPENCV_EXTRA_MODULES_PATH=/src/opencv_contrib/modules \
          -D ENABLE_PRECOMPILED_HEADERS=OFF \
          -D WITH_TBB=ON \
          -D WITH_V4L=ON \
          -D WITH_QT=ON \
          -D WITH_OPENGL=ON \
          -D WITH_FFMPEG=ON \
          -D BUILD_EXAMPLES=ON \
          -D BUILD_opencv_python3=ON \
          -D FFMPEG_INCLUDE_DIR=${OPT_APP}/ffmpeg/include \
          -D FFMPEG_LIBRARIES=${OPT_APP}/ffmpeg/lib \
          .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean

ENV PATH="$HOME/.cargo/bin:${OPT_APP}/ffmpeg/bin:${OPT_APP}/opencv/bin:$PATH"
ENV LD_LIBRARY_PATH="${OPT_APP}/ffmpeg/lib:${OPT_APP}/opencv/lib:$LD_LIBRARY_PATH"

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