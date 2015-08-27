_ = require 'lodash'
Joi = require 'joi'
router = require 'promise-router'

schemas = require '../schemas'
Experiment = require '../models/experiment'

class ExperimentCtrl
  # TODO: verify that event key isnt reserved for another tag
  create: (req) ->
    experiment = req.body or {}

    valid = Joi.validate experiment,
    _.defaults({id: schemas.experiment.id.forbidden()}, schemas.experiment)
    , {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Experiment.create experiment

  getAll: ->
    Experiment.getAll()

  delete: (req) ->
    id = req.params.id

    valid = Joi.validate {id}, {
      id: schemas.experiment.id
    }, {presence: 'required'}

    if valid.error
      throw new router.Error status: 400, detail: valid.error.message

    Experiment.deleteById(id)
    .then -> null

  update: (req) ->
    id = req.params.id
    diff = req.body

    experimentUpdateSchema =
      globalPercent: schemas.experiment.globalPercent

    diff = _.pick diff, _.keys(experimentUpdateSchema)
    updateValid = Joi.validate diff, experimentUpdateSchema

    if updateValid.error
      throw new router.Error status: 400, detail: updateValid.error.message

    Experiment.updateById id, diff
    .then ->
      Experiment.getById id


module.exports = new ExperimentCtrl()
