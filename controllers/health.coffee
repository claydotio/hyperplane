Promise = require 'bluebird'
_ = require 'lodash'

r = require '../services/rethinkdb'

HEALTHCHECK_TIMEOUT = 100

class HealthCtrl
  check: ->
    Promise.settle [
      r.dbList().run().timeout HEALTHCHECK_TIMEOUT
    ]
    .spread (rethinkdb) ->
      result =
        rethinkdb: rethinkdb.isFulfilled()

      result.healthy = _.every _.values result
      return result

  ping: -> 'pong'

module.exports = new HealthCtrl()
