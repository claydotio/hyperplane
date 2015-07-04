Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'
Promise = require 'bluebird'

config = require '../config'
schemas = require '../schemas'
Event = require '../models/event'
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

    valid = Joi.validate {
      tags: userTags
      fields: userFields
      namespace
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
      .tap ->
        log.info "event=event_create, namespace=#{namespace},
                  tags=#{JSON.stringify(tags)},
                  fields=#{JSON.stringify(fields)}"
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
