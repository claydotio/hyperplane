Promise = require 'bluebird'
_ = require 'lodash'

r = require '../services/rethinkdb'
InfluxService = require '../services/influxdb'

HEALTHCHECK_TIMEOUT = 100

class HealthCtrl
  check: ->
    Promise.settle [
      r.dbList().run().timeout HEALTHCHECK_TIMEOUT
      InfluxService.getDatabases().timeout HEALTHCHECK_TIMEOUT
    ]
    .spread (rethinkdb, influxdb) ->
      result =
        rethinkdb: rethinkdb.isFulfilled()
        influxdb: influxdb.isFulfilled()

      result.healthy = _.every _.values result
      return result

  ping: -> 'pong'

module.exports = new HealthCtrl()
