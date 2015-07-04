Joi = require 'joi'
router = require 'promise-router'
Promise = require 'bluebird'

User = require '../models/user'
config = require '../config'
schemas = require '../schemas'
Experiment = require '../models/experiment'

class UserCtrl
  loginOrCreate: (req) ->
    joinDay = req.body.joinDay

    if config.ENV isnt config.ENVS.DEV and joinDay
      throw new router.Error status: 400, detail: 'joinDay not allowed'

    user = if req.user?
      Promise.resolve req.user
    else
      User.create({joinDay})

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
