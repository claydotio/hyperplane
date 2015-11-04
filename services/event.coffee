_ = require 'lodash'
UAParser = require 'ua-parser-js'
Negotiator = require 'negotiator'
Promise = require 'bluebird'

Experiment = require '../models/experiment'

INVITER_KEY_PREFIX = 'INVITER_'

class EventService
  getTags: (req, user, app, userTags = {}, inviter = null) ->
    Promise.resolve _.defaults {app}, userTags

  getFields: (req, user, app, userFields = {}, inviter = null) ->
    parser = new UAParser req.headers['user-agent']
    negotiator = new Negotiator req

    forwardedFor = req.headers['x-forwarded-for'] or
      req.connection.remoteAddress or ''

    Experiment.assignByApp user, app
    .then (experimentGroups) ->
      _.transform experimentGroups, (result, value, key) ->
        result[app + '_' + key] = value
      , {}
    .then (experimentGroups) ->
      fields = _.defaults {
        # High cardinality
        userId: user.id
        sessionId: user.sessionId
        ip: forwardedFor.split(',')[0].trim() or null

        # Low cardinality
        uaBrowserName: parser.getBrowser().name
        uaBrowserVersionMajor: parser.getBrowser().major
        uaOSName: parser.getOS().name
        uaOSVersion: parser.getOS().version
        uaDeviceModel: parser.getDevice().model
        language: negotiator.language()
        joinDay: String user.joinDay
        inviterJoinDay: String(user.inviterJoinDay or '') or undefined
        sessionEvents: String user.sessionEvents
      }, experimentGroups

      if inviter
        fields['inviterId'] = inviter.id

      return fields
    .then (fields) ->
      _.defaults fields, userFields
    .then (fields) ->
      unless inviter
        return fields

      Experiment.assignByApp inviter, app
      .then (experimentGroups) ->
        _.transform experimentGroups, (result, value, key) ->
          result[INVITER_KEY_PREFIX + app + '_' + key] = value
        , {}
      .then (inviterFields) ->
        _.defaults fields, inviterFields

module.exports = new EventService()
