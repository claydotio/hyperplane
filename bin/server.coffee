#!/usr/bin/env coffee
log = require 'loglevel'

server = require '../'
config = require '../config'

server.listen config.PORT, ->
  log.info 'Listening on port %d', config.PORT
