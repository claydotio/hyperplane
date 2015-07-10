_ = require 'lodash'
Joi = require 'joi'
server = require '../../index'
flare = require('flare-gun').express(server.app)

schemas = require '../../schemas'
config = require '../../config'
util = require './util'

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
        .post '/users', {namespace: 'testspace'}
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
        .thru util.createUser({namespace: 'joinevent'})
        .thru util.loginAdmin()
        .get '/events', {
          q: 'SELECT count(value) FROM joinevent'
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'creates a join event with custom tags', ->
      flare
        .thru util.createUser({namespace: 'joinevent2', tags: {tagA: 'abc'}})
        .thru util.loginAdmin()
        .get '/events', {
          q: 'SELECT count(value) FROM joinevent2 WHERE tagA=\'abc\''
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
            namespace: 'valid'
          }
          .expect 200
          .post '/users', {
            namespace: 'valid'
            joinDay: '123'
          }
          .expect 400
          .post '/users', {
            namespace: 'valid'
            inviterJoinDay: '123'
          }
          .expect 400
          .post '/users', {
            namespace: 'valid'
            timestamp: String Date.now()
          }
          .expect 400

      it 'errors if invalid namespace', ->
        flare
          .post '/users', {
            namespace: 'valid'
          }
          .expect 200
          .post '/users', {
            namespace: 123
          }
          .expect 400
          .post '/users'
          .expect 400

  describe 'GET /users/me/experiments/:namespace', ->
    it 'gets users experiments in namespace', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            key: 'namespace_1_exp_1'
            namespace: 'namespace_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .post '/experiments',
          {
            key: 'namespace_1_exp_2'
            namespace: 'namespace_1'
            globalPercent: 100
            choices: ['purple', 'yellow', 'red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            key: 'namespace_1_exp_3'
            namespace: 'namespace_1'
            globalPercent: 0
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            key: 'namespace_null_exp_1'
            namespace: 'namespace_null'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .thru util.createUser({namespace: 'namespace_1'})
        .get '/users/me/experiments/namespace_1'
        .expect 200, {
          namespace_1_exp_1: 'red'
          namespace_1_exp_2:
            Joi.string().valid('purple', 'yellow', 'red', 'blue')
        }

    describe '400', ->
      it 'fails if invalid namespace', ->
        flare
          .thru util.loginAdmin()
          .post '/experiments',
            {
              key: 'namespace_2_exp_1'
              namespace: 'namespace_2'
              globalPercent: 100
              choices: ['red', 'blue']
              weights: [1, 0]
            }
          .expect 200
          .thru util.createUser({namespace: 'namespace_2'})
          .get '/users/me/experiments/in-valid'
          .expect 400
