#!/bin/sh
[ -z "$DEBUG" ] && export DEBUG=0
[ -z "$LINT" ] && export LINT=1
[ -z "$COVERAGE" ] && export COVERAGE=1
export NODE_PATH=.
export NODE_ENV=test

node_modules/gulp/bin/gulp.js test
