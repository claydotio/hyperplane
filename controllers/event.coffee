_ = require 'lodash'
Joi = require 'joi'
log = require 'loga'
router = require 'promise-router'
exoidRouter = require 'exoid-router'
Promise = require 'bluebird'

config = require '../config'
schemas = require '../schemas'
Event = require '../models/event'
User = require '../models/user'
Experiment = require '../models/experiment'
EventService = require '../services/event'

class EventCtrl
  exCreate: ({event, app, tags, fields, isInteractive}, req) ->
    userTags = tags or {}
    userFields = fields or {}
    isInteractive ?= true

    userTagValues = _.values(userTags)
    userFieldValues = _.values(userFields)

    exoidRouter.assert {
      app: app
      event: event
      userTags: userTags
      userFields: userFields
      isInteractive: isInteractive
      keys: _.keys(userTags).concat _.keys(userFields)
      strings: userTagValues.concat _.filter(userFieldValues, _.isString)
      numbers: _.filter userFieldValues, _.isNumber
    }, schemas.event

    Promise.all [
      EventService.getTags req, req.user, app, userTags
      EventService.getFields req, req.user, userFields
    ]
    .then ([tags, fields]) ->
      Event.create event, tags, fields
    .then ->
      if isInteractive
        User.cycleSession(req.user)
        .then (user) ->
          Promise.all [
            EventService.getTags req, user, app, userTags
            EventService.getFields req, user, _.defaults {
              value: user.lastSessionEventDelta
            }, userFields
          ]
        .then ([tags, fields]) ->
          # TODO: enable once database can handle data
          # Event.create 'session', tags, fields
    .then ->
      return null

  create: (req) ->
    event = req.params.event
    app = req.body?.app
    userTags = req.body?.tags or {}
    userFields = req.body?.fields or {}
    isInteractive = req.body?.isInteractive
    timestamp = req.body?.timestamp

    isInteractive ?= true

    if config.ENV isnt config.ENVS.DEV and timestamp
      throw new router.Error status: 400, detail: 'timestamp not allowed'

    userTagValues = _.values(userTags)
    userFieldValues = _.values(userFields)

    schemas.assert {
      app: app
      event: event
      userTags: userTags
      userFields: userFields
      isInteractive: isInteractive
      keys: _.keys(userTags).concat _.keys(userFields)
      strings: userTagValues.concat _.filter(userFieldValues, _.isString)
      numbers: _.filter userFieldValues, _.isNumber
    }, schemas.event

    Promise.all [
      EventService.getTags req, req.user, app, userTags
      EventService.getFields req, req.user, userFields
    ]
    .then ([tags, fields]) ->
      Event.create event, tags, fields, timestamp
    .then ->
      if isInteractive
        User.cycleSession(req.user)
        .then (user) ->
          Promise.all [
            EventService.getTags req, user, app, userTags
            EventService.getFields req, user, _.defaults {
              value: user.lastSessionEventDelta
            }, userFields
          ]
        .then ([tags, fields]) ->
          # TODO: enable once database can handle data
          # Event.create 'session', tags, fields, timestamp
    .then ->
      return null

  find: (req) ->
    q = req.body?.q
    log.info "event=find_event, q=#{q}"

    schemas.assert {q}, {q: Joi.string()}

    Event.find q

  batch: (req) ->
    queries = req.body.queries
    log.info {event: 'event_batch', count: queries.length}

    schemas.assert {queries}, {
      queries: Joi.array().items Joi.string()
    }

    Event.batch queries


module.exports = new EventCtrl()
