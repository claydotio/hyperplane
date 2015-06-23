Promise = require 'bluebird'

InfluxService = require '../services/influxdb'

class Event
  create: (namespace, tags, fields, timestamp = '') ->
    InfluxService.write namespace, tags, fields, timestamp

  find: (q) ->
    InfluxService.find q

module.exports = new Event()
