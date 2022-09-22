#!/usr/bin/env bash

rm -rf public
hugo -D

# This is https://github.com/svenkreiss/html5validator which uses
# https://github.com/validator/validator.
html5validator \
    --root public \
    --show-warnings \
    --format gnu \
    --also-check-css
