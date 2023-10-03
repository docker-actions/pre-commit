ARG ROOTFS=/build/rootfs

FROM ubuntu:jammy as build

ARG REQUIRED_PACKAGES="sed git less ncurses-base openssh-client gcc python3-dev"
ARG VERSION=3.4.0
ARG ROOTFS

ENV BUILD_DEBS /build/debs
ENV DEBIAN_FRONTEND noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE true

RUN : "${ROOTFS:?Build argument needs to be set and non-empty.}"

SHELL ["bash", "-Eeuc"]

# Build pre-requisites
RUN mkdir -p ${BUILD_DEBS} {ROOTFS}/{bin,sbin,usr/share,usr/bin,usr/sbin,usr/lib,/usr/local/bin,etc,container_user_home}

# Fix permissions
RUN chown -Rv 100:root $BUILD_DEBS

# Install pre-requisites
RUN apt-get update \
        && apt-get -y install apt-utils locales

# Build environment
RUN apt-get install -y build-essential golang ca-certificates \
      && update-ca-certificates

# Unpack required packges to rootfs
RUN cd ${BUILD_DEBS} \
  && for pkg in $REQUIRED_PACKAGES; do \
       apt-get download $pkg \
         && apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends -i $pkg | grep '^[a-zA-Z0-9]' | xargs apt-get download ; \
     done
RUN if [ "x$(ls ${BUILD_DEBS}/)" = "x" ]; then \
      echo No required packages specified; \
    else \
      for pkg in ${BUILD_DEBS}/*.deb; do \
        echo Unpacking $pkg; \
        dpkg -x $pkg ${ROOTFS}; \
      done; \
    fi

RUN apt-get update; \
    apt-get install -yq python3-pip; \
    pip3 install -vvv --upgrade --root ${ROOTFS} --force-reinstall pre-commit==${VERSION}

# Move /sbin out of the way
RUN set -Eeuo pipefail; \
    mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig; \
    mkdir -p ${ROOTFS}/sbin; \
    for b in ${ROOTFS}/sbin.orig/*; do \
      echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
      chmod +x ${ROOTFS}/sbin/$(basename $b); \
    done

COPY entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/python3:3.10.6-jammy1
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS
RUN : "${ROOTFS:?Build argument needs to be set and non-empty.}"

ENV PYTHONPATH=:/usr/lib/python310.zip:/usr/lib/python3.10:/usr/lib/python3.10/lib-dynload:/usr/lib/python3/dist-packages:/usr/local/lib/python3.10/dist-packages
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
