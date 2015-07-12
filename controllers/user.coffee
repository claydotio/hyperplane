_ = require 'lodash'
Joi = require 'joi'
router = require 'promise-router'
Promise = require 'bluebird'

User = require '../models/user'
config = require '../config'
schemas = require '../schemas'
Experiment = require '../models/experiment'
Event = require '../models/event'
EventService = require '../services/event'

class UserCtrl
  loginOrCreate: (req) ->
    namespace = req.body.namespace
    inviterId = req.body.inviterId
    userTags = _.defaults {event: 'join'}, req.body?.tags or {}
    userFields = _.defaults {value: 1}, req.body?.fields or {}

    # fake data overrides
    joinDay = req.body.joinDay
    inviterJoinDay = req.body.inviterJoinDay
    timestamp = req.body.timestamp
    hasRestrictedParams = joinDay or inviterJoinDay or timestamp

    if config.ENV isnt config.ENVS.DEV and hasRestrictedParams
      throw new router.Error {
        status: 400, detail: 'restricted params not allowed'
      }

    user = if req.user?
      Promise.resolve req.user
    else

      userValues = _.values(userTags).concat(_.values(userFields))
      valid = Joi.validate {
        namespace: namespace
        inviterId: inviterId
        tagEvent: userTags.event
        keys: _.keys(userTags).concat _.keys(userFields)
        strings: _.filter userValues, _.isString
        numbers: _.filter userValues, _.isNumber
      }, schemas.event,
        {presence: 'required'}

      if valid.error
        throw new router.Error status: 400, detail: valid.error.message

      (if inviterId
        User.getById inviterId
      else
        Promise.resolve null)
      .then (inviter) ->
        inviterJoinDay ?= inviter?.joinDay
        User.create({joinDay, inviterJoinDay})
      .tap (user) ->
        Promise.all [
          EventService.getTags namespace, req, user, userTags
          EventService.getFields req, user, userFields
        ]
        .then ([tags, fields]) ->
          Event.create namespace, tags, fields, timestamp

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
