_ = require 'lodash'
Joi = require 'joi'
server = require '../../index'
flare = require('flare-gun').express(server.app)
should = require('clay-chai').should()

schemas = require '../../schemas'
config = require '../../config'
util = require './util'
srcUtil = require '../../lib/util'

describe 'User Routes', ->
  describe 'auth.login (and users.getMe...)', ->
    it 'returns accessToken', ->
      flare
        .exoid 'auth.login', {app: 'app'}
        .expect 200, schemas.auth
        .stash 'auth'
        .actor 'user',
          qs:
            accessToken: ':auth.accessToken'
        .as 'user'
        .exoid 'users.getMe'
        .expect 200, schemas.user

    it 'creates a join event', ->
      flare
        .thru util.exCreateUser()
        .thru util.loginAdmin()
        .post '/events', {
          q: 'SELECT count(userId) FROM join'
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    it 'creates a join event with custom tags', ->
      flare
        .thru util.exCreateUser({tags: {tagA: 'abc'}})
        .thru util.loginAdmin()
        .post '/events', {
          q: 'SELECT count(userId) FROM join WHERE tagA=\'abc\''
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks inviterJoinDay', ->
      today = srcUtil.dateToDay new Date(), config.TIME_ZONE
      flare
        .thru util.exCreateUser()
        .as 'nobody'
        .exoid 'auth.login',
          app: 'app'
          inviterId: ':user.id'
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE inviterJoinDay='#{today}'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks {experiment.app}_{experimentKey} tags', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_experiment']
            key: 'exp_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.exCreateUser({app: 'test_experiment'})
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .post '/experiments',
          {
            apps: ['xxx', 'test_experiment']
            key: 'exp_2'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.exCreateUser({app: 'test_experiment'})
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_2='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE xxx_exp_2='red'"
        }
        .expect 200, ({body}) ->
          should.not.exist body.results[0].series
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2

    it 'tracks INVITER_{experiment} tags', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_inviter']
            key: 'invi_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.exCreateUser({app: 'test_inviter'})
        .as 'nobody'
        .exoid 'auth.login',
          app: 'test_inviter'
          inviterId: ':user.id'
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE INVITER_test_inviter_invi_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    describe '400', ->
      it 'errors if invalid inviterId', ->
        flare
          .exoid 'auth.login', {
            inviterId: true
          }
          .expect 400

  describe 'users.getExperimentsByApp', ->
    it 'gets users experiments', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_namespace']
            key: 'flappy_bird'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test2', 'test_namespace']
            key: 'flappy_angry_bird'
            globalPercent: 100
            choices: ['purple', 'yellow', 'red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test_namespace']
            key: 'angry_bird'
            globalPercent: 0
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test2']
            key: 'angry_bird'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .thru util.exCreateUser()
        .exoid 'users.getExperimentsByApp', {app: 'test_namespace'}
        .expect 200, Joi.object().keys {
          flappy_bird: 'red'
          flappy_angry_bird:
            Joi.string().valid('purple', 'yellow', 'red', 'blue')
        }

    it 'allows experimentKey overrides', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_override']
            key: 'override_exp_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [0.5, 0.5]
          }
        .expect 200
        .thru util.exCreateUser({experimentKey: '2'})
        .exoid 'users.getExperimentsByApp', {app: 'test_override'}
        .expect 200, Joi.object().keys {
          override_exp_1: 'blue'
        }

    describe '400', ->
      it 'rejects invalid experimentKey', ->
        flare
          .as 'nobody'
          .exoid 'auth.login',
            experimentKey: 123
          .expect 400


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

    it 'logs in admin with accessToken in query string', ->
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
          qs:
            accessToken: ':admin.accessToken'
        }
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.adminUser

    it 'returns new user with accessToken', ->
      flare
        .post '/users', {app: 'app'}
        .expect 200, _.defaults {
          accessToken: schemas.accessToken
        }, schemas.user
        .stash 'user'
        .post '/users', {app: 'app'}, {
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
        .post '/events', {
          q: 'SELECT count(userId) FROM join'
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    it 'creates a join event with custom tags', ->
      flare
        .thru util.createUser({tags: {tagA: 'abc'}})
        .thru util.loginAdmin()
        .post '/events', {
          q: 'SELECT count(userId) FROM join WHERE tagA=\'abc\''
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    it 'tracks inviterJoinDay', ->
      today = srcUtil.dateToDay new Date(), config.TIME_ZONE
      flare
        .thru util.createUser()
        .as 'nobody'
        .post '/users',
          app: 'app'
          inviterId: ':user.id'
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE inviterJoinDay='#{today}'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    it 'tracks {experiment.app}_{experimentKey} tags', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_experiment']
            key: 'exp_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.createUser({app: 'test_experiment'})
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1
        .post '/experiments',
          {
            apps: ['xxx', 'test_experiment']
            key: 'exp_2'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.createUser({app: 'test_experiment'})
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_2='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE xxx_exp_2='red'"
        }
        .expect 200, ({body}) ->
          should.not.exist body.results[0].series
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE test_experiment_exp_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 2

    it 'tracks INVITER_{experiment} tags', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_inviter']
            key: 'invi_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .thru util.createUser({app: 'test_inviter'})
        .as 'nobody'
        .post '/users',
          app: 'test_inviter'
          inviterId: ':user.id'
        .thru util.loginAdmin()
        .post '/events', {
          q: "SELECT count(userId) FROM join
              WHERE INVITER_test_inviter_invi_1='red'"
        }
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be.least 1

    describe '400', ->
      it 'errors if invalid admin info', ->
        flare
          .get '/users/me/experiments/app',
            {
              auth:
                username: 'invalid'
                password: config.ADMIN_PASSWORD
            }
          .expect 401
          .get '/users/me/experiments/app',
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

  describe 'GET /users/me/experiments/:app', ->
    it 'gets users experiments', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_namespace']
            key: 'flappy_bird'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [1, 0]
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test2', 'test_namespace']
            key: 'flappy_angry_bird'
            globalPercent: 100
            choices: ['purple', 'yellow', 'red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test_namespace']
            key: 'angry_bird'
            globalPercent: 0
            choices: ['red', 'blue']
          }
        .expect 200
        .post '/experiments',
          {
            apps: ['test2']
            key: 'angry_bird'
            globalPercent: 100
            choices: ['red', 'blue']
          }
        .expect 200
        .thru util.createUser()
        .get '/users/me/experiments/test_namespace'
        .expect 200, Joi.object().keys {
          flappy_bird: 'red'
          flappy_angry_bird:
            Joi.string().valid('purple', 'yellow', 'red', 'blue')
        }

    it 'allows experimentKey overrides', ->
      flare
        .thru util.loginAdmin()
        .post '/experiments',
          {
            apps: ['test_override']
            key: 'override_exp_1'
            globalPercent: 100
            choices: ['red', 'blue']
            weights: [0.5, 0.5]
          }
        .expect 200
        .thru util.createUser({experimentKey: '2'})
        .get '/users/me/experiments/test_override'
        .expect 200, Joi.object().keys {
          override_exp_1: 'blue'
        }

    describe '400', ->
      it 'rejects invalid experimentKey', ->
        flare
          .as 'nobody'
          .post '/users',
            experimentKey: 123
          .expect 400
