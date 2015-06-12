_ = require 'lodash'
server = require '../../index'
flare = require('flare-gun').express(server.app)

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
