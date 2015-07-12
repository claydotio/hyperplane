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
    userTags = req.body?.tags or {}
    userFields = req.body?.fields or {}
    timestamp = req.body?.timestamp or ''
    namespace = req.params.namespace

    if config.ENV isnt config.ENVS.DEV and timestamp
      throw new router.Error status: 400, detail: 'timestamp not allowed'

    userValues = _.values(userTags).concat(_.values(userFields))
    valid = Joi.validate {
      namespace: namespace
      tagEvent: userTags.event
      keys: _.keys(userTags).concat _.keys(userFields)
      strings: _.filter userValues, _.isString
      numbers: _.filter userValues, _.isNumber
    }, schemas.event,
      {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Promise.all [
      EventService.getTags namespace, req, req.user, userTags
      EventService.getFields req, req.user, userFields
    ]
    .then ([tags, fields]) ->
      Event.create namespace, tags, fields, timestamp
    .then ->
      User.cycleSession(req.user)
    .then (user) ->
      Promise.all [
        EventService.getTags namespace, req, user, {event: 'session'}
        EventService.getFields req, user, {
          value: user.lastSessionEventDelta
        }
      ]
    .then ([tags, fields]) ->
      Event.create namespace, tags, fields, timestamp
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
