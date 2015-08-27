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
            apps: ['test_app']
            key: 'text_exp'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200, _.defaults {
          apps: schemas.experiment.apps.length(1)
          key: 'text_exp'
          globalPercent: 100
          choices: schemas.experiment.choices.length(2)
        }, schemas.experiment

    it 'creates an experiment with weights', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_app']
            key: 'text_exp'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [0.3, 0.7]
          }
        .expect 200, _.defaults {
          apps: schemas.experiment.apps.length(1)
          key: 'text_exp'
          globalPercent: 100
          choices: schemas.experiment.choices.length(2)
          weights: schemas.experiment.weights.length(2)
        }, schemas.experiment

    it 'creates an experiment with multiple apps', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['abc', 'xyz']
            key: 'abc_xyz_text_exp'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200, _.defaults {
          apps: schemas.experiment.apps.length(2)
          key: 'abc_xyz_text_exp'
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
              apps: ['test_app']
              key: 'text_exp'
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 401

      it 'fails if not admin', ->
        flare
          .thru util.createUser()
          .post '/experiments',
            {
              apps: ['test_app']
              key: 'text_exp'
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
            apps: ['test']
            key: 'abc'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test_2', 'test']
            key: 'xyz'
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
            apps: ['test']
            key: 'abc'
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

    describe '400', ->
      it 'fails if invalid data', ->
        flare
          .thru util.loginAdmin()
          .post '/experiments',
            {
              apps: ['test']
              key: 'abc'
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 200
          .stash 'experiment'
          .put '/experiments/:experiment.id', {
            globalPercent: 'str'
          }
          .expect 400

    describe 'DELETE /experiments/:id', ->
      it 'deletes experiments', ->
        flare
          .thru util.loginAdmin()
          .post '/experiments',
            {
              apps: ['test']
              key: 'abc'
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 200
          .stash 'experiment'
          .del '/experiments/:experiment.id'
          .expect 204
          .get '/experiments'
          .expect 200, Joi.array().items _.defaults {
            id: schemas.experiment.id.invalid(':experiment.id')
          }, schemas.experiment

      describe '400', ->
        it 'fails if invalid id', ->
          flare
            .thru util.loginAdmin()
            .del '/experiments/-1'
            .expect 400
