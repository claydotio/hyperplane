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

JOIN_EVENT_KEY = 'join'

class UserCtrl
  loginOrCreate: (req) ->
    inviterId = req.body.inviterId
    userTags = req.body?.tags or {}
    userFields = req.body?.fields or {}

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

      userTagValues = _.values(userTags)
      valid = Joi.validate {
        inviterId: inviterId
        event: JOIN_EVENT_KEY
        keys: _.keys(userTags).concat _.keys(userFields)
        strings: userTagValues.concat _.filter(_.values(userFields), _.isString)
        numbers: _.filter _.values(userFields), _.isNumber
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
          EventService.getTags req, user, userTags
          EventService.getFields req, user, userFields
        ]
        .then ([tags, fields]) ->
          Event.create JOIN_EVENT_KEY, tags, fields, timestamp

    user.then User.embed ['accessToken']
    .then (user) ->
      User.sanitize(user.id, user)

  getExperiments: (req) ->
    Experiment.assign req.user.id

module.exports = new UserCtrl()
