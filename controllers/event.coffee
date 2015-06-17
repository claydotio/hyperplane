_ = require 'lodash'
Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'
UAParser = require 'ua-parser-js'
Negotiator = require 'negotiator'
Promise = require 'bluebird'

schemas = require '../schemas'
Event = require '../models/event'
Experiment = require '../models/experiment'

getTags = (userTags, req, user, namespace) ->
  parser = new UAParser req.headers['user-agent']
  negotiator = new Negotiator req

  Experiment.assign user.id
  .then (namespaces) ->
    _.defaults {
      uaBrowserName: parser.getBrowser().name
      uaBrowserVersionMajor: parser.getBrowser().major
      uaOSName: parser.getOS().name
      uaOSVersion: parser.getOS().version
      uaDeviceModel: parser.getDevice().model
      language: negotiator.language()
      joinTimeS: user.joinTimeS
    }, namespaces[namespace]
  .then (tags) ->
    _.defaults tags, userTags

getFields = (userFields, req, user) ->
  _.defaults {
    userId: user.id
    ip: req.headers['x-forwards-for'] or req.connection.remoteAddress
  }, userFields


class EventCtrl
  create: (req) ->
    userTags = req.body?.tags or {}
    userFields = req.body?.fields or {}
    namespace = req.params.namespace

    valid = Joi.validate {
      tags: userTags
      fields: userFields
      namespace
    }, schemas.event,
      {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Promise.all [
      getTags userTags, req, req.user, namespace
      getFields userFields, req, req.user
    ]
    .then ([tags, fields]) ->
      Event.create namespace, tags, fields
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
