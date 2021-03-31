FROM debian:buster-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yqq && \
    apt-get install -y \
            devscripts \
            build-essential \
            sbuild \
            schroot \
            debootstrap \
            pbuilder \
            && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#COPY profiler /profiler
COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]