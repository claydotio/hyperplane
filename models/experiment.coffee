_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'
seedrandom = require 'seedrandom'
log = require 'loga'

r = require '../services/rethinkdb'
config = require '../config'

EXPERIMENTS_TABLE = 'experiments'

defaultExperiment = (experiment) ->
  unless experiment?
    return null

  _.merge {
    id: uuid.v4()
    apps: []
    key: null
    globalPercent: 100
    choices: []
    createdAt: new Date()
  }, experiment

assignExperiment = (experiment, userId) ->
  seed = experiment.key + userId
  rng = seedrandom seed

  isInGlobalScope = rng() * 100 < experiment.globalPercent

  unless isInGlobalScope
    return undefined

  {choices, weights} = experiment
  weights ?= _.map _.range(choices.length), -> 1
  weightSum = _.sum weights

  normalizedWeights = _.reduce weights, (result, weight) ->
    previous = _.last(result) or 0

    result.concat [weight / weightSum + previous]
  , []

  choiceRand = rng()

  choiceIndex = _.findIndex normalizedWeights, (weight) ->
    choiceRand <= weight

  return choices[choiceIndex]

class Experiment
  RETHINK_TABLES: [
    {
      NAME: EXPERIMENTS_TABLE
    }
  ]
  create: (experiment) ->
    experiment = defaultExperiment experiment

    r.table EXPERIMENTS_TABLE
    .insert experiment
    .run()
    .then ->
      log.info "event=experiment_create, id=#{experiment.id}"
      experiment

  getById: (id) ->
    r.table EXPERIMENTS_TABLE
    .get id
    .run()
    .then defaultExperiment

  getAll: ->
    r.table EXPERIMENTS_TABLE
    .run()
    .map defaultExperiment

  updateById: (id, diff) ->
    r.table EXPERIMENTS_TABLE
    .get id
    .update diff
    .run()

  deleteById: (id) ->
    r.table EXPERIMENTS_TABLE
    .get id
    .delete()
    .run()

  assignByApp: (user, app, experimentKey = null) =>
    experimentKey ?= user.experimentKey

    @getAll().then (experiments) ->
      appExperiments = _.filter experiments, (experiment) ->
        _.includes experiment.apps, app
      _.reduce appExperiments, (result, experiment) ->
        assigned = assignExperiment experiment, experimentKey

        if assigned?
          result[experiment.key] = assigned

        return result
      , {}


module.exports = new Experiment()
