#!/bin/bash

pushd "$(dirname "$0")"

forge test -vv && \
./analyze.sh

popd