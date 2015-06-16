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
        .post '/users',
          {
            username: 'admin'
            password: config.ADMIN_PASSWORD
          }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.adminUser

    it 'logs in admin with accessToken', ->
      flare
        .post '/users',
          {
            username: 'admin'
            password: config.ADMIN_PASSWORD
          }
        .expect 200
        .stash 'admin'
        .post '/users', {}, {
          oauth:
            token: ':admin.accessToken'
        }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.adminUser

    it 'returns new user if invalid admin info', ->
      flare
        .post '/users',
          {
            username: 'invalid'
            password: config.ADMIN_PASSWORD
          }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user
        .post '/users',
          {
            username: 'admin'
            password: 'invalid'
          }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user

    it 'returns new user with accessToken', ->
      flare
        .post '/users'
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user
        .stash 'user'
        .post '/users', {}, {
          oauth:
            token: ':user.accessToken'
        }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user

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
        .thru util.createUser()
        .get '/users/me/experiments/namespace_1'
        .expect 200, {
          namespace_1_exp_1: 'red'
          namespace_1_exp_2:
            Joi.string().valid('purple', 'yellow', 'red', 'blue')
        }
