#!/usr/bin/env coffee
log = require 'loga'
Promise = require 'bluebird'

server = require '../'
config = require '../config'

Promise.all [server.rethinkSetup(), server.influxSetup()]
.then ->
  server.app.listen config.PORT, ->
    log.info 'Listening on port %d', config.PORT
