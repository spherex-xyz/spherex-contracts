#!/bin/bash

pushd "$(dirname "$0")"

pipenv run slither .
pipenv run myth analyze --max-depth 5 src/*.sol

popd