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
        .thru util.createUser({namespace: 'doodledraw'})
        .post '/events/doodledraw',
          {
            tags:
              event: 'signup'
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .post '/events/doodledraw',
          {
            tags:
              event: 'signup'
            fields:
              value: 1
          }
        .expect 204

    describe '400', ->
      it 'fails to create event if invalid value', ->
        flare
          .thru util.createUser({namespace: 'doodledraw'})
          .post '/events/doodledraw',
            {
              tags:
                event: 'signup'
                refererHost: 'google.com'
              fields:
                value: 'str'
            }
          .expect 400
          .post '/events/doodledraw',
            {
              tags:
                event: 'signup'
                refererHost: 'google.com'
            }
          .expect 400
          .post '/events/doodledraw',
            {
              tags:
                refererHost: 'google.com'
              fields:
                value: 1
            }
          .expect 400

      it 'fails to create if timestamp given in non dev environment', ->
        flare
          .thru util.createUser({namespace: 'doodledraw'})
          .post '/events/doodledraw',
            {
              timestamp: String Date.now()
              tags:
                event: 'signup'
              fields:
                value: 1
            }
          .expect 400

  describe 'GET /events/?q=', ->
    it 'gets experiment results', ->
      flare
        .thru util.createUser({namespace: 'gspace'})
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
              event: 'cancel'
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .thru util.loginAdmin()
        .get '/events',
          q: "SELECT count(value) FROM gspace
              WHERE refererHost='google.com'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2

    it 'gets experiment results for auto added tags', ->
      flare
        .thru util.createUser({namespace: 'exspace'})
        .post '/events/exspace',
          {
            tags:
              event: 'view'
            fields:
              value: 1
          }, {
            headers:
              'user-agent': 'Mozilla/5.0 (Linux; Android 4.4.2;
                            Nexus 5 Build/KOT49H) AppleWebKit/537.36
                            (KHTML, like Gecko) Chrome/32.0.1700.99
                            Mobile Safari/537.36'
          }
        .expect 204
        .post '/events/exspace',
          {
            tags:
              event: 'cancel_order'
            fields:
              value: 1
          }, {
            headers:
              'user-agent': 'Mozilla/5.0 (Linux; Android 4.4.2;
                            Nexus 5 Build/KOT49H) AppleWebKit/537.36
                            (KHTML, like Gecko) Chrome/32.0.1700.99
                            Mobile Safari/537.36'
          }
        .expect 204
        .thru util.createUser({namespace: 'exspace'})
        .post '/events/exspace',
          {
            tags:
              event: 'view'
            fields:
              value: 1
          }, {
            headers:
              'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 6_0
                            like Mac OS X) AppleWebKit/536.26
                            (KHTML, like Gecko) Version/6.0
                            Mobile/10A5376e Safari/8536.25'
          }
        .expect 204
        .post '/events/exspace',
          {
            tags:
              event: 'cancel_order'
            fields:
              value: 1
          }, {
            headers:
              'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 6_0
                            like Mac OS X) AppleWebKit/536.26
                            (KHTML, like Gecko) Version/6.0
                            Mobile/10A5376e Safari/8536.25'
              'accept-language': 'en-US'
          }
        .expect 204
        .thru util.loginAdmin()
        .get '/events',
          q: "SELECT count(value) FROM exspace
              WHERE event='view'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2
        .get '/events',
          q: "SELECT count(value) FROM exspace
              WHERE uaBrowserName='Chrome' AND event='view'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .get '/events',
          q: "SELECT count(value) FROM exspace
              WHERE event='cancel_order' AND language='en-US'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    describe '400', ->
      it 'fails if missing q', ->
        flare
          .thru util.loginAdmin()
          .get '/events'
          .expect 400
