_ = require 'lodash'

schemas = require '../schemas'
Experiment = require '../models/experiment'

class ExperimentCtrl
  # TODO: verify that event key isnt reserved for another tag
  create: (req) ->
    experiment = req.body or {}

    schemas.assert experiment,
    _.defaults({id: schemas.experiment.id.forbidden()}, schemas.experiment)

    Experiment.create experiment

  getAll: ->
    Experiment.getAll()

  delete: (req) ->
    id = req.params.id

    schemas.assert {id}, {
      id: schemas.experiment.id
    }

    Experiment.deleteById(id)
    .then -> null

  update: (req) ->
    id = req.params.id
    diff = req.body

    experimentUpdateSchema =
      globalPercent: schemas.experiment.globalPercent.optional()

    diff = _.pick diff, _.keys(experimentUpdateSchema)
    schemas.assert diff, experimentUpdateSchema

    Experiment.updateById id, diff
    .then ->
      Experiment.getById id


module.exports = new ExperimentCtrl()
