_ = require 'lodash'
Promise = require 'bluebird'
log = require 'loglevel'

InfluxService = require '../services/influxdb'
redis = require '../services/redis'
config = require '../config'

PREFIX = config.REDIS.PREFIX + ':event'

dateToDay = (date) ->
  Math.floor(date / 1000 / 60 / 60 / 24)

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
  now = new Date()
  today = dateToDay now
  dateToDay(date) < today

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
