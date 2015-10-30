_ = require 'lodash'
Promise = require 'bluebird'
log = require 'loga'
os = require 'os'

InfluxService = require '../services/influxdb'
redis = require '../services/redis'
config = require '../config'
util = require '../lib/util'

OS_CPUS = os.cpus().length
PREFIX = config.REDIS.PREFIX + ':event'
QUERY_EXPIRE_TIME_SECONDS = 5 * 60 # 5 min - release all queries back to pool
UNCACHEABLE_EXPIRE_TIME_SECONDS = 60 * 60 # 1hr

timeSuffixToMs = (time, suffix) ->
  Math.floor switch suffix
    when 'n'
      time / 1e6
    when 'u'
      time / 1e3
    when 'ms'
      time
    when 's'
      time * 1e3
    when 'm'
      time * 1e3 * 60
    when 'h'
      time * 1e3 * 60 * 60
    when 'd'
      time * 1e3 * 60 * 60 * 24
    else
      time

isValidDate = (date) ->
  date < new Date()

isCacheable = (query) ->
  hasSpecificTimeRange = /\stime\s?(<|<=|=)/.test(query) and
    not /now\(\)/.test query

  alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  invalidLetters = _.filter alphabet, (letter) ->
    not _.contains ['n', 'u', 's', 'm', 'h', 'd'], letter
  dateMatch = query.match ///
    time\s?(<|<=|=)\s?
    ([^#{invalidLetters}]+)
    ///

  hasValidTime = if dateMatch?
    [match, operator, time] = dateMatch
    timeMatch = match.match ///
      (\d+)             # time in number format
      (n|u|ms|s|m|h|d)? # valid time suffix
    ///

    date = new Date(time)
    if isNaN(date) and timeMatch
      [match, numberPart, suffix] = timeMatch
      suffix ?= 'u'
      numberPart = parseInt(numberPart)
      isValidDate new Date(timeSuffixToMs(numberPart, suffix))
    else if not isNaN(date)
      isValidDate date
    else
      false
  else
    false

  return hasSpecificTimeRange and hasValidTime

class Event
  create: (event, tags, fields, timestampNS) ->
    InfluxService.write event, tags, fields, timestampNS
    .tap ->
      log.info "event=event_create, event=#{event},
                tags=#{JSON.stringify(tags)},
                fields=#{JSON.stringify(fields)}"

  batch: (queries) ->
    cacheKeys = _.map queries, (query) -> "#{PREFIX}:batch:#{query}"
    redis.mgetAsync cacheKeys
    .then (redisCached) ->
      # return to the user only what's in redis
      response = _.map redisCached, (result, index) ->
        if result?
          JSON.parse(result)
        else
          {query: queries[index], isPending: true}

      return {response, redisCached}
    .tap ({redisCached}) ->
      # create redis keys so that other instances know we're working on these
      uncached = _.filter queries, (query, index) ->
        not redisCached[index]?

      log.info {event: 'batch_reserve', count: uncached.length}
      batchStartTime = new Date()
      skipCount = 0

      if _.isEmpty uncached
        return null

      redis.msetAsync _.flatten _.map uncached, (query) ->
        [
          "#{PREFIX}:batch:#{query}"
          JSON.stringify {query, isPending: true}
        ]
      .then ->
        # If a response isn't set within QUERY_EXPIRE_TIME_SECONDS, clear it
        Promise.map uncached, (query) ->
          redis.expireAsync "#{PREFIX}:batch:#{query}",
            QUERY_EXPIRE_TIME_SECONDS
      .then ->
        # Actually query InfluxDB and store the results in redis
        Promise.map uncached, (query) ->
          totalElapsedMs = new Date() - batchStartTime
          if totalElapsedMs > QUERY_EXPIRE_TIME_SECONDS * 1000
            skipCount += 1
            return null
          startTime = new Date()
          InfluxService.find query
          .then (response) ->
            toCache = {query: query, isPending: false, response}
            redis.setAsync "#{PREFIX}:batch:#{query}", JSON.stringify toCache
          .catch (err) ->
            log.error err
            redis.delAsync "#{PREFIX}:batch:#{query}"
          .then ->
            if not isCacheable query
              redis.expireAsync "#{PREFIX}:batch:#{query}",
                UNCACHEABLE_EXPIRE_TIME_SECONDS
          .then ->
            log.info {
              event: 'batch_query'
              query
              elapsed: new Date() - startTime
            }
        , {concurrency: OS_CPUS}
      .then ->
        log.info {
          event: 'batch_completed'
          count: uncached.length - skipCount
          skipped: skipCount
          elapsed: new Date() - batchStartTime
        }
      .catch log.error

      # Don't block, run in the background
      return null
    .then ({response}) ->
      return {results: response}

  find: (q) ->
    queries = _.map q.split('\n'), _.trim
    cacheKeys = _.map queries, (query) -> "#{PREFIX}:#{query}"

    redis.mgetAsync cacheKeys
    .then (redisCached) ->
      cached = _.map redisCached, (result, index) ->
        # Check cache here because that logic may change but we don't
        # want to manually clear existing caches
        if result? and isCacheable queries[index]
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
          result = response.results[uncachedQueries.indexOf(query)]
          if isCacheable(query) and result? and not result.error
            [
              "#{PREFIX}:#{query}"
              JSON.stringify result
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
