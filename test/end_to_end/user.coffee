_ = require 'lodash'
Joi = require 'joi'
server = require '../../index'
flare = require('flare-gun').express(server.app)

schemas = require '../../schemas'
config = require '../../config'
util = require './util'

MS_IN_DAY = 1000 * 60 * 60 * 24

describe 'User Routes', ->
  describe 'POST /users', ->
    it 'logs in admin with username and password', ->
      flare
        .post '/users', {},
          {
            auth:
              username: 'admin'
              password: config.ADMIN_PASSWORD
          }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.adminUser

    it 'logs in admin with accessToken', ->
      flare
        .post '/users', {},
          {
            auth:
              username: 'admin'
              password: config.ADMIN_PASSWORD
          }
        .expect 200
        .stash 'admin'
        .post '/users', {}, {
          headers:
            Authorization: 'Token :admin.accessToken'
        }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.adminUser

    it 'returns new user with accessToken', ->
      flare
        .post '/users'
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user
        .stash 'user'
        .post '/users', {}, {
          headers:
            Authorization: 'Token :user.accessToken'
        }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user

    it 'creates a join event', ->
      flare
        .thru util.createUser()
        .thru util.loginAdmin()
        .get '/events', {
          q: 'SELECT count(userId) FROM join'
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    it 'creates a join event with custom tags', ->
      flare
        .thru util.createUser({tags: {tagA: 'abc'}})
        .thru util.loginAdmin()
        .get '/events', {
          q: 'SELECT count(userId) FROM join WHERE tagA=\'abc\''
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks inviterJoinDay', ->
      today = Math.floor Date.now() / MS_IN_DAY
      flare
        .thru util.createUser()
        .as 'nobody'
        .post '/users',
          inviterId: ':user.id'
        .thru util.loginAdmin()
        .get '/events', {
          q: "SELECT count(userId) FROM join
              WHERE inviterJoinDay='#{today}'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    describe '400', ->
      it 'errors if invalid admin info', ->
        flare
          .post '/users', {},
            {
              auth:
                username: 'invalid'
                password: config.ADMIN_PASSWORD
            }
          .expect 401
          .post '/users', {},
            {
              auth:
                username: 'admin'
                password: 'invalid'
            }
          .expect 401

      it 'errors if contains restricted params in non-dev environment', ->
        flare
          .post '/users', {
            joinDay: '123'
          }
          .expect 400
          .post '/users', {
            inviterJoinDay: '123'
          }
          .expect 400
          .post '/users', {
            timestamp: String Date.now()
          }
          .expect 400

      it 'errors if invalid inviterId', ->
        flare
          .post '/users', {
            inviterId: true
          }
          .expect 400

  describe 'GET /users/me/experiments', ->
    it 'gets users experiments', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'flappy_bird_exp_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .post '/experiments',
          {
            key: 'flappy_bird_exp_2'
            globalPercent: 100
            choices: ['purple', 'yellow', 'red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            key: 'flappy_bird_exp_3'
            globalPercent: 0
            choices: ['red', 'blue']
          }
        .expect 200
        .thru util.createUser()
        .get '/users/me/experiments'
        .expect 200, Joi.object().unknown().keys {
          flappy_bird_exp_1: 'red'
          flappy_bird_exp_2:
            Joi.string().valid('purple', 'yellow', 'red', 'blue')
        }
