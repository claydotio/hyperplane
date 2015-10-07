request = require 'clay-request'
_ = require 'lodash'
Promise = require 'bluebird'

config = require '../config'

FIND_THROTTLE_DELAY_MS = 10

escape = (str) ->
  str
  .replace /\\/g, '\\\\'
  .replace /,/g, '\\,'
  .replace /"/g, '\\"'
  .replace /\s/g, '\\ '
  .replace /\=/g, '\\='

join = (obj, quoteStrings) ->
  _.filter _.map obj, (val, key) ->
    key = escape(key)

    if _.isNumber(val)
      "#{key}=#{val}i"
    else if _.isBoolean(val)
      "#{key}=#{val}"
    else if _.isString val
      val = escape(val)
      if quoteStrings
        "#{key}=\"#{val}\""
      else
        "#{key}=#{val}"
    else
      null
  .join ','

class InfluxService
  constructor: ->
    @findThrottle = Promise.resolve null

  write: (measurement, tags, fields, timestampNS = '') ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/write",
      method: 'POST'
      qs:
        db: config.INFLUX.DB
      body: """
        #{measurement},#{join(tags)} #{join(fields, true)} #{timestampNS}
      """

  find: (q) =>
    @findThrottle = @findThrottle
    .delay FIND_THROTTLE_DELAY_MS
    .then ->
      request \
      "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
        qs:
          q: q
          db: config.INFLUX.DB
      }

  createDatabase: (db) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
      qs:
        q: "CREATE DATABASE #{db}"
    }

  dropDatabase: (db) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
      qs:
        q: "DROP DATABASE #{db}"
    }

  ping: ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/ping"

  getDatabases: ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
      qs:
        q: 'SHOW DATABASES'
    }
    .then ({results}) ->
      _.flatten results?[0]?.series?[0].values

  alterRetentionPolicyDuration: (db, policy, durationDays) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
      qs:
        q: "ALTER RETENTION POLICY #{policy} ON #{db} DURATION #{durationDays}d"
    }

module.exports = new InfluxService()
