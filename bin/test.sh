#!/bin/sh
[ -z "$DEBUG" ] && export DEBUG=0
[ -z "$LINT" ] && export LINT=1
[ -z "$COVERAGE" ] && export COVERAGE=1
export NODE_PATH=.
export NODE_ENV=test
export HYPERPLANE_RETHINK_DB=hyperplane_test
export HYPERPLANE_INFLUX_DB=hyperplane_test
export HYPERPLANE_REDIS_PREFIX=hyperplane_test

node_modules/gulp/bin/gulp.js test
