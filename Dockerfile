FROM ruby:3.4.5-alpine

RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ttf-freefont \
    ca-certificates \
    git \
    build-base \
    tzdata

ENV BROWSER_PATH=/usr/bin/chromium-browser
WORKDIR /work