FROM ubuntu:kinetic as builder
# Using kinetic to get Python 3.10, used by Poetry

ARG WKDIR=/usr/local/src
WORKDIR ${WKDIR}

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Get build dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install -y \
		build-essential \
		software-properties-common \
		ninja-build \
		python3-pip \
		bc \
		wget \
		ca-certificates \
		git-all \
		cmake


# we need meson for libvips build
RUN pip3 install meson

# libvips dependencies
RUN apt-get install --no-install-recommends -y \
	glib-2.0-dev \
	libexpat-dev \
	librsvg2-dev \
	libpng-dev \
	libjpeg-turbo8-dev \
	libtiff-dev \
	libexif-dev \
	liblcms2-dev \
	libheif-dev \
	liborc-dev \
    libgirepository1.0-dev \
	libopenslide-dev


RUN update-ca-certificates
# Install libvips from source to get latest version
ENV LD_LIBRARY_PATH /usr/local/lib
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig

ARG VIPS_VERSION=8.14.1
ARG VIPS_URL=https://github.com/libvips/libvips/releases/download


# build the head of the stable 8.14 branch
RUN wget ${VIPS_URL}/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz --no-check-certificate \
	&& tar xf vips-${VIPS_VERSION}.tar.xz \
	&& cd vips-${VIPS_VERSION} \
	&& meson build --buildtype=release --libdir=lib \
	&& cd build \
	&& ninja \
	&& ninja install

RUN rm vips-${VIPS_VERSION}.tar.xz
RUN rm -r vips-${VIPS_VERSION}



# Install python packages using poetry
COPY . .

RUN pip3 install --upgrade pip
RUN pip3 install poetry && poetry config virtualenvs.in-project true


RUN pip3 install poetry
RUN poetry remove aicspylibczi
RUN poetry install --only main

# Set path to use .venv Python
ENV PATH="${WKDIR}/.venv/bin:$PATH"

# Install python packages that can't be installed with poetry/pip (pep517)
RUN . .venv/bin/activate
ARG CZI_DIR=./aicspylibczi
RUN git config --global http.sslVerify false
RUN git clone https://github.com/AllenCellModeling/aicspylibczi.git ${CZI_DIR} --recurse-submodules
WORKDIR ${CZI_DIR}
RUN pip install -e .[dev] # for development (-e means editable so changes take effect when made)

WORKDIR ${WKDIR}


# Install bioformats.jar in valis
ARG BF_VERSION=6.12.0
RUN wget https://downloads.openmicroscopy.org/bio-formats/${BF_VERSION}/artifacts/bioformats_package.jar -P valis

# Clean up
RUN  apt-get remove -y wget build-essential ninja-build && \
  apt-get autoremove -y && \
  apt-get autoclean && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  rm -rf /usr/local/lib/python*


# Copy over only what is needed to run, but not build, the package.
FROM ubuntu:kinetic

ARG WKDIR=/usr/local/src
WORKDIR ${WKDIR}

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /usr/local/src /usr/local/src

ENV LD_LIBRARY_PATH /usr/local/lib
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig
ENV PATH="${WKDIR}/.venv/bin:$PATH"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y \
	glib-2.0-dev \
	libexpat-dev \
	librsvg2-dev \
	libpng-dev \
	libjpeg-turbo8-dev \
	libtiff-dev \
	libexif-dev \
	liblcms2-dev \
	libheif-dev \
	liborc-dev \
	libgirepository1.0-dev \
	libopenslide-dev \
	libjxr-dev

# Install other non-Python dependencies
RUN apt-get install -y \
    openjdk-11-jre
