FROM ubuntu:18.04

# ENV is used here but also for installing dependencies 
# at container runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y git && \
    apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY . /app
WORKDIR /app
