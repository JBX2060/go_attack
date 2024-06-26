# To build, navigate to the *root* of this repo and run:
# docker build . -f compose/cpp/Dockerfile -t humancompatibleai/goattack:cpp
#
# Commands to build alternative targets:
# docker build . -f compose/cpp/Dockerfile -t humancompatibleai/goattack:cpp-build-deps --target build-*
#
# KataGo has been tested on CUDA 11.1 with CUDNN 8.0.4
# See https://github.com/lightvector/KataGo/blob/master/Compiling.md.
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu20.04 AS build-deps

ENV DEBIAN_FRONTEND=noninteractive

# Update Nvidia signing key
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub

# Install apt packages
RUN apt-get update -q \
  && apt-get install -y \
  # Utilities
  curl \
  git \
  sudo \
  tmux \
  unzip \
  vim \
  wget \
  # Packages needed to compile KataGo/cpp
  gcc \
  gdb \
  libgoogle-perftools-dev \
  libssl-dev \
  libzip-dev \
  zlib1g-dev \
  # Clean up
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN wget https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.2.0%2Bcu118.zip \
  && unzip libtorch-cxx11-abi-shared-with-deps-2.2.0+cu118.zip -d /opt \
  && rm libtorch-cxx11-abi-shared-with-deps-2.2.0+cu118.zip

# Install cmake
# Instructions from https://cliutils.gitlab.io/modern-cmake/chapters/intro/installing.html
RUN wget -qO- "https://cmake.org/files/v3.22/cmake-3.22.0-linux-x86_64.tar.gz" \
  | tar --strip-components=1 -xz -C /usr/local

# Copy over KataGo cpp files and compile.
# See https://github.com/lightvector/KataGo/blob/master/Compiling.md.

FROM build-deps as build-raw
COPY ./engines/KataGo-raw/cpp /engines/KataGo-raw/cpp
WORKDIR /engines/KataGo-raw/cpp
RUN cmake . -DUSE_BACKEND=CUDA -DUSE_TCMALLOC=1 -DNO_GIT_REVISION=1
RUN make clean && make -j

FROM build-deps as build-custom
COPY ./engines/KataGo-custom/cpp /engines/KataGo-custom/cpp
WORKDIR /engines/KataGo-custom/cpp
RUN cmake . -DUSE_BACKEND=CUDA -DUSE_TCMALLOC=1 -DNO_GIT_REVISION=1
RUN make clean && make -j

FROM build-deps as build-custom-debug
COPY ./engines/KataGo-custom/cpp /engines/KataGo-custom/cpp
WORKDIR /engines/KataGo-custom/cpp
RUN cmake . -DUSE_BACKEND=CUDA -DUSE_TCMALLOC=1 -DNO_GIT_REVISION=1 -DBUILD_DEBUG=1
RUN make clean && make -j

# Actual production image, without development headers.
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu20.04 AS runtime-deps

ENV DEBIAN_FRONTEND=noninteractive

# Update Nvidia signing key
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub

# Install useful apt packages
RUN apt-get update -q \
  && apt-get install -y \
  # Utilities
  cron \
  curl \
  gdb \
  git \
  gpustat \
  htop \
  netcat \
  python3 \
  python3-pip \
  rsync \
  socat \
  sudo \
  tmux \
  unzip \
  uuid-runtime \
  vim \
  wget \
  # KataGo runtime libraries
  libgoogle-perftools4 \
  libssl1.1 \
  libzip5 \
  zlib1g \
  # Clean up
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build-deps /opt/libtorch /opt/libtorch

# Reset working directory
WORKDIR /

# Install Python packages
RUN python3 -m pip install --upgrade pip

# Copy over python files and install them.
RUN mkdir -p /go_attack/src
COPY ./src/go_attack /go_attack/src/go_attack
COPY ./setup.py /go_attack/setup.py
COPY README.md /go_attack/README.md
# Silence annoying pip warning about running it as root inside the container
RUN pip install -e /go_attack --root-user-action=ignore

# Copy over other files
COPY ./scripts/ /go_attack/scripts
COPY ./engines/KataGo-raw/cpp/configs /engines/KataGo-raw/cpp/configs

# Debug image
FROM runtime-deps as debug
COPY --from=build-custom-debug /engines/KataGo-custom/cpp/katago /engines/KataGo-custom/cpp/katago
COPY ./kubernetes/ /go_attack/kubernetes
COPY ./configs /go_attack/configs

# Production image
FROM runtime-deps as prod
COPY --from=build-raw /engines/KataGo-raw/cpp/katago /engines/KataGo-raw/cpp/katago
COPY --from=build-custom /engines/KataGo-custom/cpp/katago /engines/KataGo-custom/cpp/katago
RUN ln -s /engines /go_attack/engines

COPY ./kubernetes/ /go_attack/kubernetes
COPY ./configs /go_attack/configs

# Make the git commit visible to the image if provided as a --build-arg
ARG ARG_GIT_COMMIT
ENV GIT_COMMIT=$ARG_GIT_COMMIT
