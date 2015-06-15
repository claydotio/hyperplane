request = require 'clay-request'
_ = require 'lodash'

config = require '../config'

keyValue = (obj) ->
  str = _.reduce obj, (res, val, key) ->
    res += "#{encodeURIComponent(key)}=#{encodeURIComponent(val)},"
  , ''

  str.slice(0, str.length - 1) # strip trailing comma


class InfluxService
  write: (namespace, tags, fields) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/write",
      method: 'POST'
      qs:
        db: config.INFLUX.DB
      body: """
        #{encodeURIComponent(namespace)},#{keyValue(tags)} #{keyValue(fields)}
      """

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
      results?[0]?.series?[0].values?[0]

  alterRetentionPolicyDuration: (db, policy, durationDays) ->
    request "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}/query", {
      qs:
        q: "ALTER RETENTION POLICY #{policy} ON #{db} DURATION #{durationDays}d"
    }

module.exports = new InfluxService()
