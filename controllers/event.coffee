_ = require 'lodash'
Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'
Promise = require 'bluebird'

config = require '../config'
schemas = require '../schemas'
Event = require '../models/event'
User = require '../models/user'
Experiment = require '../models/experiment'
EventService = require '../services/event'

class EventCtrl
  create: (req) ->
    event = req.params.event
    userTags = req.body?.tags or {}
    userFields = req.body?.fields or {}
    isInteractive = req.body?.isInteractive
    timestamp = req.body?.timestamp

    isInteractive ?= true

    if config.ENV isnt config.ENVS.DEV and timestamp
      throw new router.Error status: 400, detail: 'timestamp not allowed'

    userTagValues = _.values(userTags)
    userFieldValues = _.values(userFields)
    valid = Joi.validate {
      event: event
      keys: _.keys(userTags).concat _.keys(userFields)
      strings: userTagValues.concat _.filter(userFieldValues, _.isString)
      numbers: _.filter userFieldValues, _.isNumber
    }, schemas.event,
      {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Promise.all [
      EventService.getTags req, req.user, userTags
      EventService.getFields req, req.user, userFields
    ]
    .then ([tags, fields]) ->
      Event.create event, tags, fields, timestamp
    .then ->
      if isInteractive
        User.cycleSession(req.user)
        .then (user) ->
          Promise.all [
            EventService.getTags req, user, userTags
            EventService.getFields req, user, _.defaults {
              value: user.lastSessionEventDelta
            }, userFields
          ]
        .then ([tags, fields]) ->
          Event.create 'session', tags, fields, timestamp
    .then ->
      return null

  find: (req) ->
    q = req.query?.q

    valid = Joi.validate {q},
    {
      q: Joi.string()
    }, {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Event.find q


module.exports = new EventCtrl()
