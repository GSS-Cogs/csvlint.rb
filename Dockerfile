FROM ruby:2.4.3-alpine

RUN \
  apk --no-cache -t .dev add build-base git libcurl

VOLUME /workspace
WORKDIR /workspace