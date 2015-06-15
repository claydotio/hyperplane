_ = require 'lodash'
Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'

schemas = require '../schemas'
Event = require '../models/event'

class EventCtrl
  create: (req) ->
    tags = _.pick(req.body?.tags or {}, Object.keys(schemas.event.tags))
    fields = _.pick(req.body?.fields or {}, Object.keys(schemas.event.fields))
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


module.exports = new EventCtrl()
