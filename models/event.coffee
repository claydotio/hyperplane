_ = require 'lodash'
Promise = require 'bluebird'
log = require 'loglevel'

InfluxService = require '../services/influxdb'
redis = require '../services/redis'
config = require '../config'

PREFIX = config.REDIS.PREFIX + ':event'

isCacheable = (query) ->
  hasSpecificTimeRange = _.indexOf(query, ' time <') isnt -1 and
    _.indexOf(query, 'now()') is -1
  return hasSpecificTimeRange

class Event
  create: (event, tags, fields, timestampNS) ->
    InfluxService.write event, tags, fields, timestampNS
    .tap ->
      log.info "event=event_create, event=#{event},
                tags=#{JSON.stringify(tags)},
                fields=#{JSON.stringify(fields)}"
  find: (q) ->
    queries = _.map q.split('\n'), _.trim
    cacheKeys = _.map queries, (query) -> "#{PREFIX}:#{query}"

    redis.mgetAsync cacheKeys
    .then (redisCached) ->
      cached = _.map redisCached, (result) ->
        if result?
          JSON.parse(result)
        else
          null

      uncachedQueries = _.filter queries, (query, index) ->
        return not cached[index]?

      if _.isEmpty uncachedQueries
        return {results: _.values(cached)}

      InfluxService.find uncachedQueries.join '\n'
      .tap (response) ->
        redisCacheable = _.flatten _.filter _.map uncachedQueries, (query) ->
          if isCacheable query
            [
              "#{PREFIX}:#{query}"
              JSON.stringify response.results[uncachedQueries.indexOf(query)]
            ]
        unless _.isEmpty redisCacheable
          redis.msetAsync redisCacheable
      .then (response) ->
        mergedResults = _.map queries, (query, index) ->
          if cached[index]?
            return cached[index]
          response.results[uncachedQueries.indexOf(query)]
        return _.defaults {results: mergedResults}, response

module.exports = new Event()
