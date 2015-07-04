Joi = require 'joi'
router = require 'promise-router'
Promise = require 'bluebird'
log = require 'loglevel'

User = require '../models/user'
config = require '../config'
schemas = require '../schemas'
Experiment = require '../models/experiment'
Event = require '../models/event'
EventService = require '../services/event'

class UserCtrl
  loginOrCreate: (req) ->
    joinDay = req.body.joinDay
    inviterJoinDay = req.body.inviterJoinDay
    namespace = req.body.namespace # FIXME: validate
    timestamp = req.body.timestamp # FIXME: invalidate

    if config.ENV isnt config.ENVS.DEV and (joinDay or inviterJoinDay)
      throw new router.Error {
        status: 400, detail: 'joinDay and inviterJoinDay not allowed'
      }

    user = if req.user?
      Promise.resolve req.user
    else
      User.create({joinDay, inviterJoinDay})
      .tap (user) ->
        Promise.all [
          EventService.getTags namespace, req, user, {event: 'join'}
          EventService.getFields req, user, {value: 1}
        ]
        .then ([tags, fields]) ->
          Event.create namespace, tags, fields, timestamp
          .tap ->
            # FIXME: move to model
            log.info "event=event_create, namespace=#{namespace},
                      tags=#{JSON.stringify(tags)},
                      fields=#{JSON.stringify(fields)}"

    user.then User.embed ['accessToken']
    .then (user) ->
      User.sanitize(user.id, user)

  getExperiments: (req) ->
    namespace = req.params.namespace

    valid = Joi.validate {namespace},
      namespace: schemas.experiment.namespace
    , {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Experiment.assign req.user.id
    .then (namespaces) ->
      return namespaces[namespace]


module.exports = new UserCtrl()
