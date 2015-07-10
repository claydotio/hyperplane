_ = require 'lodash'
server = require '../../index'
flare = require('flare-gun').express(server.app)
Joi = require 'joi'

schemas = require '../../schemas'
config = require '../../config'
util = require './util'

describe 'Experiment Routes', ->
  describe 'POST /experiments', ->
    it 'creates an experiment', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'text_exp'
            namespace: 'ex_name_space'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200, _.defaults {
          key: 'text_exp'
          namespace: 'ex_name_space'
          globalPercent: 100
          choices: schemas.experiment.choices.length(2)
        }, schemas.experiment

    it 'creates an experiment with weights', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'text_exp'
            namespace: 'ex_name_space'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [0.3, 0.7]
          }
        .expect 200, _.defaults {
          key: 'text_exp'
          namespace: 'ex_name_space'
          globalPercent: 100
          choices: schemas.experiment.choices.length(2)
          weights: schemas.experiment.weights.length(2)
        }, schemas.experiment

    describe '400', ->
      it 'fails if invalid params', ->
        flare
          .thru util.loginAdmin()
          .post '/experiments',
            {
              key: 123
            }
          .expect 400

      it 'fails if not authed', ->
        flare
          .post '/experiments',
            {
              key: 'text_exp'
              namespace: 'ex_name_space'
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 401

      it 'fails if not admin', ->
        flare
          .thru util.createUser({namespace: 'ex_name_space'})
          .post '/experiments',
            {
              key: 'text_exp'
              namespace: 'ex_name_space'
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 403

  describe 'GET /experiments', ->
    it 'gets all experiments', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'abc'
            namespace: 'ex_name_space'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            key: 'xyz'
            namespace: 'ex_name_space'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .get '/experiments'
        .expect 200, Joi.array().min(2).items schemas.experiment

  describe 'PUT /experiments/:id', ->
    it 'updates experiments', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'abc'
            namespace: 'ex_name_space'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .stash 'experiment'
        .put '/experiments/:experiment.id',
          {
            globalPercent: 5
          }
        .expect 200, _.defaults {
          globalPercent: 5
        }, schemas.experiment
