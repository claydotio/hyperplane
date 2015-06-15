_ = require 'lodash'
should = require('clay-chai').should()
server = require '../../index'
flare = require('flare-gun').express(server.app)

schemas = require '../../schemas'
config = require '../../config'
util = require './util'

describe 'Event Routes', ->
  describe 'POST /events/:namespace', ->
    it 'creates event', ->
      flare
        .thru util.createUser()
        .post '/events/doodledraw',
          {
            tags:
              event: 'signup'
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204

  describe 'GET /events/?q=', ->
    it 'gets experiment results', ->
      flare
        .thru util.createUser()
        .post '/events/gspace',
          {
            tags:
              event: 'signup'
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .post '/events/gspace',
          {
            tags:
              event: 'signup'
              refererHost: 'clay.io'
            fields:
              value: 1
          }
        .expect 204
        .post '/events/gspace',
          {
            tags:
              event: 'signup'
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .thru util.loginAdmin()
        .get '/events',
          q: "SELECT count(value) FROM gspace
              WHERE event='signup' AND refererHost='google.com'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2
