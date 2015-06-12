Joi = require 'joi'
log = require 'loglevel'
router = require 'promise-router'

schemas = require '../schemas'
Experiment = require '../models/experiment'

class ExperimentCtrl
  create: (req) ->
    experiment = req.body or {}

    valid = Joi.validate experiment,
      key: schemas.experiment.key
      globalPercent: schemas.experiment.globalPercent
      choices: schemas.experiment.choices
    , {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Experiment.create experiment
    .then (experiment) ->
      Experiment.getById experiment.id
    .tap (experiment) ->
      log.info "event=experiment_create, id=#{experiment.id}"


module.exports = new ExperimentCtrl()
