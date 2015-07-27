_ = require 'lodash'
Promise = require 'bluebird'
log = require 'loglevel'

InfluxService = require '../services/influxdb'
redis = require '../services/redis'
config = require '../config'

PREFIX = config.REDIS.PREFIX + ':event'

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
        redis.msetAsync _.flatten _.map uncachedQueries, (query) ->
          [
            "#{PREFIX}:#{query}"
            JSON.stringify response.results[uncachedQueries.indexOf(query)]
          ]
      .then (response) ->
        mergedResults = _.map queries, (query, index) ->
          if cached[index]?
            return cached[index]
          response.results[uncachedQueries.indexOf(query)]
        return _.defaults {results: mergedResults}, response

module.exports = new Event()
