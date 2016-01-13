Promise = require 'bluebird'
_ = require 'lodash'

r = require '../services/rethinkdb'
InfluxService = require '../services/influxdb'
redis = require '../services/redis'

HEALTHCHECK_TIMEOUT = 1000

class HealthCtrl
  check: ->
    Promise.settle [
      r.dbList().run().timeout HEALTHCHECK_TIMEOUT
      InfluxService.ping().timeout HEALTHCHECK_TIMEOUT
      InfluxService.write(
        'healthcheck',
        {healthy: 'true'},
        {value: 1}
      ).timeout HEALTHCHECK_TIMEOUT
      redis.getAsync('NULL').timeout HEALTHCHECK_TIMEOUT
    ]
    .spread (rethinkdb, influxdb, influxdbWrite, redis) ->
      result =
        rethinkdb: rethinkdb.isFulfilled()
        influxdb: influxdb.isFulfilled()
        influxdbWrite: influxdbWrite.isFulfilled()
        redis: redis.isFulfilled()

      result.healthy = _.every _.values result
      return result

  ping: -> 'pong'

module.exports = new HealthCtrl()
