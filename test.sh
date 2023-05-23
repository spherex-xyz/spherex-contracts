#!/bin/bash

pushd "$(dirname "$0")"

forge test -vv --use 0.6.2 && \
forge test -vv --use 0.7.0 && \
forge test -vv --use 0.8.0 && \
forge test -vv && \
./analyze.sh

popd