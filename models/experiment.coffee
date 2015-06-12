_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'

r = require '../services/rethinkdb'
config = require '../config'

EXPERIMENTS_TABLE = 'experiments'

defaultExperiment = (experiment) ->
  _.defaults experiment, {
    id: uuid.v4()
    key: null
    globalPercent: 100
    choices: []
  }


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


module.exports = new Experiment()
