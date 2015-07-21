_ = require 'lodash'
UAParser = require 'ua-parser-js'
Negotiator = require 'negotiator'

Experiment = require '../models/experiment'

INVITER_KEY_PREFIX = 'INVITER_'

class EventService
  getTags: (req, user, userTags, inviter = null) ->
    parser = new UAParser req.headers['user-agent']
    negotiator = new Negotiator req

    Experiment.assign user
    .then (experimentGroups) ->
      _.defaults {
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
    .then (tags) ->
      _.defaults tags, userTags
    .then (tags) ->
      unless inviter
        return tags

      Experiment.assign inviter
      .then (experimentGroups) ->
        _.transform experimentGroups, (result, value, key) ->
          result[INVITER_KEY_PREFIX + key] = value
        , {}
      .then (inviterTags) ->
        _.defaults tags, inviterTags

  getFields: (req, user, userFields, inviter = null) ->
    fields = _.defaults {
      userId: user.id
      sessionId: user.sessionId
      ip: req.headers['x-forwarded-for'] or req.connection.remoteAddress
    }, userFields

    if inviter
      fields['inviterId'] = inviter.id

    return fields

module.exports = new EventService()
