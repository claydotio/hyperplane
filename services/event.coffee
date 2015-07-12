_ = require 'lodash'
UAParser = require 'ua-parser-js'
Negotiator = require 'negotiator'

Experiment = require '../models/experiment'

class EventService
  getTags: (namespace, req, user, userTags) ->
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
        joinDay: user.joinDay
        inviterJoinDay: user.inviterJoinDay or undefined
        sessionEvents: String user.sessionEvents
      }, namespaces[namespace]
    .then (tags) ->
      _.defaults tags, userTags

  getFields: (req, user, userFields) ->
    _.defaults {
      userId: user.id
      sessionId: user.sessionId
      ip: req.headers['x-forwards-for'] or req.connection.remoteAddress
    }, userFields

module.exports = new EventService()
