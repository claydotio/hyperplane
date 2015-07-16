request = require 'clay-request'
_ = require 'lodash'

config = require '../config'

escape = (str) ->
  str
  .replace /\//g, '\\\\'
  .replace /,/g, '\\,'
  .replace /"/g, '\\"'
  .replace /\s/g, '\\ '

join = (obj, quoteStrings) ->
  str = _.reduce obj, (res, val, key) ->
    if _.isNumber(val) or _.isBoolean(val)
      res + "#{escape(key)}=#{val},"
    else if _.isString val
      if quoteStrings
        res + "#{escape(key)}=\"#{escape(val)}\","
      else
        res + "#{escape(key)}=#{escape(val)},"
    else
      res
  , ''

  str.slice(0, str.length - 1) # strip trailing comma


class InfluxService
  write: (measurement, tags, fields, timestampNS = '') ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/write",
      method: 'POST'
      qs:
        db: config.INFLUX.DB
      body: """
        #{measurement},#{join(tags)} #{join(fields, true)} #{timestampNS}
      """

  find: (q) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
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
