#!/usr/bin/env coffee
log = require 'loglevel'

server = require '../'
config = require '../config'

server.rethinkSetup().then ->
  server.app.listen config.PORT, ->
    log.info 'Listening on port %d', config.PORT
