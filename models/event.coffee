Promise = require 'bluebird'

InfluxService = require '../services/influxdb'

class Event
  create: (namespace, tags, fields) ->
    InfluxService.write namespace, tags, fields

module.exports = new Event()
