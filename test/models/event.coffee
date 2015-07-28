_ = require 'lodash'
rewire = require 'rewire'
Promise = require 'bluebird'

Event = rewire '../../models/event'

describe 'Event Model', ->
  it 'gets cached event results', ->
    influxCalled = false
    Event.__with__({
      'redis.mgetAsync': (queries) ->
        Promise.resolve _.map queries, ->
          JSON.stringify {series: []}
      'InfluxService.find': ->
        influxCalled = true
        Promise.resolve({results: []})
    }) ->
      Event.find "
        SELECT count(userId) FROM cache WHERE refererHost='google.com'\n
        SELECT count(userId) FROM cache WHERE refererHost='clay.io'
      "
    .then ->
      if influxCalled
        throw new Error 'cache miss'

  it 'does not cache queries with unspecified time ranges', ->
    Event.__with__({
      'redis.mset': ->
        throw new Error 'no caching allowed'
    }) ->
      Event.find "
        SELECT count(userId) FROM cache WHERE refererHost='google.com'\n
        SELECT count(userId) FROM cache WHERE refererHost='clay.io'
      "
