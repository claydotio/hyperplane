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
        .post '/events',
          q: "SELECT count(userId) FROM share
              WHERE refererHost='google.com'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'gets cached event results', ->
      firstReqStart = null
      firstReqTime = null
      secondReqStart = null
      flare
        .thru util.createUser()
        .post '/events/cache',
          {
            tags:
              refererHost: 'google.com'
          }
        .expect 204
        .post '/events/cache',
          {
            tags:
              refererHost: 'clay.io'
          }
        .expect 204
        .thru util.loginAdmin()
        .thru (flare) ->
          firstReqStart = Date.now()
          return flare
        .post '/events',
          q: "SELECT count(userId) FROM cache
              WHERE refererHost='google.com'\n
              SELECT count(userId) FROM cache
                  WHERE refererHost='clay.io'"
        .thru (flare) ->
          firstReqTime = Date.now() - firstReqStart
          return flare
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
          body.results[1].series[0].values[0][1].should.be 1
        .thru (flare) ->
          secondReqStart = Date.now()
          return flare
        .post '/events',
          q: "SELECT count(userId) FROM cache
              WHERE refererHost='google.com'\n
              SELECT count(userId) FROM cache
                  WHERE refererHost='clay.io'"
        .thru (flare) ->
          secondReqTime = Date.now() - secondReqStart
          (firstReqTime >= secondReqTime).should.be true
          return flare
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
          body.results[1].series[0].values[0][1].should.be 1


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
        .post '/events',
          q: 'SELECT count(value) FROM view'
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2
        .post '/events',
          q: "SELECT count(value) FROM view
              WHERE uaBrowserName='Chrome'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .post '/events',
          q: "SELECT count(value) FROM \"cancel_order\"
              WHERE language='en-US'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks session events', ->
      flare
        .thru util.createUser()
        .post '/events/click'
        .expect 204
        .post '/events/click'
        .expect 204
        .thru util.createUser()
        .post '/events/click'
        .expect 204
        .post '/events/click'
        .expect 204
        .post '/events/click', {tags: {tagA: 'tagged'}}
        .expect 204
        .thru util.loginAdmin()
        .post '/events',
          q: "SELECT count(distinct(sessionId)) FROM click
              WHERE sessionEvents='2'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1
        .post '/events',
          q: "SELECT count(distinct(sessionId)) FROM click
              WHERE sessionEvents='1'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 2
        .post '/events',
          q: "SELECT count(distinct(sessionId)) FROM session
              WHERE tagA='tagged'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'doesn\'t track session events when not labeled as interactive', ->
      flare
        .thru util.createUser()
        .post '/events/isinteractive', tags: {xx: 'x'}
        .expect 204
        .thru util.createUser()
        .post '/events/isinteractive', {isInteractive: false, tags: {xx: 'x'}}
        .expect 204
        .thru util.loginAdmin()
        .post '/events',
          q: "SELECT count(distinct(sessionId)) FROM session
              WHERE xx='x'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    describe '400', ->
      it 'fails if missing q', ->
        flare
          .thru util.loginAdmin()
          .post '/events'
          .expect 400
