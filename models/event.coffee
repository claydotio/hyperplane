Promise = require 'bluebird'
log = require 'loglevel'

InfluxService = require '../services/influxdb'

class Event
  create: (event, tags, fields, timestamp = '') ->
    InfluxService.write event, tags, fields, timestamp
    .tap ->
      log.info "event=event_create, event=#{event},
                tags=#{JSON.stringify(tags)},
                fields=#{JSON.stringify(fields)}"
  find: (q) ->
    InfluxService.find q

module.exports = new Event()
