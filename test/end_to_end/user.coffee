_ = require 'lodash'
server = require '../../index'
flare = require('flare-gun').express(server.app)

schemas = require '../../schemas'
config = require '../../config'

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
