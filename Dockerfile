FROM crops/poky:debian-11

WORKDIR /build

USER root

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    curl \
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/*

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > /bin/repo && chmod a+x /bin/repo

COPY build.sh /usr/bin/

USER usersetup
