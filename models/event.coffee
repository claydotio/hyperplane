Promise = require 'bluebird'
log = require 'loglevel'

InfluxService = require '../services/influxdb'

class Event
  create: (namespace, tags, fields, timestamp = '') ->
    InfluxService.write namespace, tags, fields, timestamp
    .tap ->
      log.info "event=event_create, namespace=#{namespace},
                tags=#{JSON.stringify(tags)},
                fields=#{JSON.stringify(fields)}"
  find: (q) ->
    InfluxService.find q

module.exports = new Event()
