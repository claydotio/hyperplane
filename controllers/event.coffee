_ = require 'lodash'
Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'

schemas = require '../schemas'
Event = require '../models/event'

class EventCtrl
  create: (req) ->
    tags = req.body?.tags or {}
    fields = req.body?.fields or {}
    namespace = req.params.namespace

    valid = Joi.validate {tags, fields, namespace}, schemas.event,
      {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Event.create namespace, tags, fields
    .tap ->
      log.info "event=event_create, namespace=#{namespace},
                tags=#{JSON.stringify(tags)}, fields=#{JSON.stringify(fields)}"
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
