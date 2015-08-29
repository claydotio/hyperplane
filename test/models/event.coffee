_ = require 'lodash'
rewire = require 'rewire'
Promise = require 'bluebird'
assert = require 'assert'

config = require '../../config'
util = require '../../lib/util'
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
        SELECT count(id) FROM cache WHERE referer='google.com and time < 100d'\n
        SELECT count(id) FROM cache WHERE referer='clay.io and time < 100d'
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

  it 'determines cacheability using parsed times', ->
    isCacheable = Event.__get__('isCacheable')
    nowMicroseconds = new Date() * 1000
    pastMicroseconds = new Date('2013-08-13') * 1000
    nowDay = util.dateToDay new Date(), config.TIME_ZONE
    pastDay = util.dateToDay new Date('2013-08-13'), config.TIME_ZONE
    nowHours = util.dateToHour new Date(), config.TIME_ZONE
    pastHours = util.dateToHour new Date('2013-08-13'), config.TIME_ZONE

    # base
    assert.equal isCacheable('WHERE z=1'), false

    # time as date
    assert.equal isCacheable("WHERE time < '3000-08-13'"), false
    assert.equal isCacheable("WHERE time < '2013-08-13'"), true

    # now()
    assert.equal isCacheable("WHERE time < now() - #{pastMicroseconds}"), false

    # past time as microseconds
    assert.equal isCacheable("WHERE time > #{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time >= #{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time = #{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time < #{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time <= #{pastMicroseconds}"), true

    # current time as microseconds
    assert.equal isCacheable("WHERE time > #{nowMicroseconds}"), false
    assert.equal isCacheable("WHERE time >= #{nowMicroseconds}"), false
    assert.equal isCacheable("WHERE time = #{nowMicroseconds}"), false
    assert.equal isCacheable("WHERE time < #{nowMicroseconds}"), false
    assert.equal isCacheable("WHERE time <= #{nowMicroseconds}"), false

    # past time as day
    assert.equal isCacheable("WHERE time > #{pastDay}d"), false
    assert.equal isCacheable("WHERE time >= #{pastDay}d"), false
    assert.equal isCacheable("WHERE time = #{pastDay}d"), true
    assert.equal isCacheable("WHERE time < #{pastDay}d"), true
    assert.equal isCacheable("WHERE time <= #{pastDay}d"), true

    # current time as day
    assert.equal isCacheable("WHERE time > #{nowDay}d"), false
    assert.equal isCacheable("WHERE time >= #{nowDay}d"), false
    assert.equal isCacheable("WHERE time = #{nowDay}d"), false
    assert.equal isCacheable("WHERE time <= #{nowDay}d"), false

    # false for simplicity
    assert.equal isCacheable("WHERE time < #{nowDay}d"), false

    # past time as hours
    assert.equal isCacheable("WHERE time > #{pastHours}h"), false
    assert.equal isCacheable("WHERE time >= #{pastHours}h"), false
    assert.equal isCacheable("WHERE time = #{pastHours}h"), true
    assert.equal isCacheable("WHERE time < #{pastHours}h"), true
    assert.equal isCacheable("WHERE time <= #{pastHours}h"), true

    # current time as hours
    assert.equal isCacheable("WHERE time > #{nowHours}h"), false
    assert.equal isCacheable("WHERE time >= #{nowHours}h"), false
    assert.equal isCacheable("WHERE time = #{nowHours}h"), false
    assert.equal isCacheable("WHERE time < #{nowHours}h"), false
    assert.equal isCacheable("WHERE time <= #{nowHours}h"), false

    # spacing
    assert.equal isCacheable("WHERE time>#{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time=#{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time<#{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time>=#{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time<=#{pastMicroseconds}"), true

    assert.equal isCacheable("WHERE time >#{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time =#{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time <#{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time >=#{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time <=#{pastMicroseconds}"), true

    assert.equal isCacheable("WHERE time> #{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time= #{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time< #{pastMicroseconds}"), true
    assert.equal isCacheable("WHERE time>= #{pastMicroseconds}"), false
    assert.equal isCacheable("WHERE time<= #{pastMicroseconds}"), true
