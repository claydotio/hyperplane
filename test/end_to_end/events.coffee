_ = require 'lodash'
should = require('clay-chai').should()
server = require '../../index'
flare = require('flare-gun').express(server.app)

schemas = require '../../schemas'
config = require '../../config'
util = require './util'

describe 'Event Routes', ->
  describe 'POST /events', ->
    it 'creates event', ->
      flare
        .thru util.createUser()
        .post '/events/signup',
          {
            tags:
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .post '/events/signup'
        .expect 204

    describe '400', ->
      it 'fails to create if timestamp given in non dev environment', ->
        flare
          .thru util.createUser()
          .post '/events/signup',
            {
              timestamp: String Date.now()
              fields:
                value: 1
            }
          .expect 400

      it 'fails to create event with float fields', ->
        flare
          .thru util.createUser()
          .post '/events/signup',
            {
              fields:
                value: 1.1
            }
          .expect 400

      it 'fails to create event with non-string tags', ->
        flare
          .thru util.createUser()
          .post '/events/signup',
            {
              tags:
                bool: true
            }
          .expect 400

  describe 'GET /events/?q=', ->
    it 'gets event results', ->
      flare
        .thru util.createUser()
        .post '/events/share',
          {
            tags:
              refererHost: 'google.com'
          }
        .expect 204
        .post '/events/share',
          {
            tags:
              refererHost: 'clay.io'
          }
        .expect 204
        .post '/events/cancel',
          {
            tags:
              refererHost: 'google.com'
          }
        .expect 204
        .thru util.loginAdmin()
        .get '/events',
          q: "SELECT count(userId) FROM share
              WHERE refererHost='google.com'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'gets experiment results for auto added tags', ->
      flare
        .thru util.createUser()
        .post '/events/view',
          {
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
        .post '/events/cancel_order',
          {
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
        .thru util.createUser()
        .post '/events/view',
          {
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
        .post '/events/cancel_order',
          {
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
          q: 'SELECT count(value) FROM view'
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2
        .get '/events',
          q: "SELECT count(value) FROM view
              WHERE uaBrowserName='Chrome'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .get '/events',
          q: "SELECT count(value) FROM \"cancel_order\"
              WHERE language='en-US'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks session events', ->
      # delay required to avoid de-duplication
      delay = (ms) ->
        (val) ->
          new Promise (resolve) ->
            setTimeout ->
              resolve val
            , ms
      flare
        .thru util.createUser()
        .post '/events/click'
        .expect 204
        .thru delay(1000)
        .post '/events/click'
        .expect 204
        .thru util.createUser()
        .post '/events/click'
        .expect 204
        .thru delay(1000)
        .post '/events/click'
        .expect 204
        .thru delay(1000)
        .post '/events/click'
        .expect 204
        .thru util.loginAdmin()
        .get '/events',
          q: "SELECT count(distinct(sessionId)) FROM click
              WHERE sessionEvents='2'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .get '/events',
          q: "SELECT count(distinct(sessionId)) FROM click
              WHERE sessionEvents='1'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2

    describe '400', ->
      it 'fails if missing q', ->
        flare
          .thru util.loginAdmin()
          .get '/events'
          .expect 400
