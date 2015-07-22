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
    inviterId = req.body?.inviterId
    userTags = req.body?.tags
    userFields = req.body?.fields
    experimentKey = req.body?.experimentKey

    # fake data overrides
    joinDay = req.body?.joinDay
    inviterJoinDay = req.body?.inviterJoinDay
    timestamp = req.body?.timestamp
    hasRestrictedParams = joinDay or inviterJoinDay or timestamp

    if config.ENV isnt config.ENVS.DEV and hasRestrictedParams
      throw new router.Error {
        status: 400, detail: 'restricted params not allowed'
      }

    user = if req.user?
      Promise.resolve req.user
    else

      userTagValues = _.values(userTags)
      userFieldValues = _.values(userFields)
      eventValid = Joi.validate {
        inviterId: inviterId
        event: JOIN_EVENT_KEY
        keys: _.keys(userTags).concat _.keys(userFields)
        strings: userTagValues.concat _.filter(userFieldValues, _.isString)
        numbers: _.filter userFieldValues, _.isNumber
      }, schemas.event,
        {presence: 'required'}

      if eventValid.error
        throw new router.Error status: 400, detail: eventValid.error.message

      userValid = Joi.validate {experimentKey}, {
        experimentKey: schemas.user.experimentKey.optional()
      }, {presence: 'required'}

      if userValid.error
        throw new router.Error status: 400, detail: userValid.error.message

      (if inviterId
        User.getById inviterId
      else
        Promise.resolve null)
      .then (inviter) ->
        inviterJoinDay ?= inviter?.joinDay
        User.create({joinDay, inviterJoinDay, experimentKey})
        .tap (user) ->
          Promise.all [
            EventService.getTags req, user, userTags, inviter
            EventService.getFields req, user, userFields, inviter
          ]
          .then ([tags, fields]) ->
            Event.create JOIN_EVENT_KEY, tags, fields, timestamp

    user.then User.embed ['accessToken']
    .then (user) ->
      User.sanitize(user.id, user)

  getExperiments: (req) ->
    Experiment.assign req.user

module.exports = new UserCtrl()
