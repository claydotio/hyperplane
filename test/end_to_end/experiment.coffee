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
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200, _.defaults {
          key: 'text_exp'
          globalPercent: 100
          choices: schemas.experiment.choices.length(2)
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
              globalPercent: 100
              choices: ['red', 'blue']
            }
          .expect 401

      it 'fails if not admin', ->
        flare
          .thru util.createUser()
          .post '/experiments',
            {
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
            key: 'abc'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            key: 'xyz'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .get '/experiments'
        .expect 200, Joi.array().min(2).items schemas.experiment
