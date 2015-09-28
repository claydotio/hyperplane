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
            app: 'app'
            tags:
              refererHost: 'google.com'
            fields:
              value: 1
          }
        .expect 204
        .post '/events/signup', {app: 'app'}
        .expect 204

    describe '400', ->
      it 'fails to create if timestamp given in non dev environment', ->
        flare
          .thru util.createUser()
          .post '/events/signup',
            {
              app: 'app'
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
              app: 'app'
              fields:
                value: 1.1
            }
          .expect 400

      it 'fails to create event with non-string tags', ->
        flare
          .thru util.createUser()
          .post '/events/signup',
            {
              app: 'app'
              tags:
                bool: true
            }
          .expect 400

      it 'fails to create event without app', ->
        flare
          .thru util.createUser()
          .post '/events/signup'
          .expect 400

  describe 'GET /events/?q=', ->
    it 'gets event results', ->
      flare
        .thru util.createUser()
        .post '/events/share',
          {
            app: 'app'
            tags:
              refererHost: 'google.com'
          }
        .expect 204
        .post '/events/share',
          {
            app: 'app'
            tags:
              refererHost: 'clay.io'
          }
        .expect 204
        .post '/events/cancel',
          {
            app: 'app'
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

    it 'gets experiment results for auto added tags and fields', ->
      flare
        .thru util.createUser()
        .post '/events/view',
          {
            app: 'app'
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
            app: 'app'
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
            app: 'app'
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
            app: 'app'
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
        .post '/events',
          q: "SELECT count(value) FROM \"view\"
              WHERE uaBrowserName='Chrome' AND ip = '127.0.0.1'"
        .expect 200, ({body}) ->
          body.results[0].series[0].values[0][1].should.be 1

    it 'tracks session events', ->
      flare
        .thru util.createUser()
        .post '/events/click', {app: 'app'}
        .expect 204
        .post '/events/click', {app: 'app'}
        .expect 204
        .thru util.createUser()
        .post '/events/click', {app: 'app'}
        .expect 204
        .post '/events/click', {app: 'app'}
        .expect 204
        .post '/events/click', {app: 'app', tags: {tagA: 'tagged'}}
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
        .post '/events/isinteractive', {app: 'app', tags: {xx: 'x'}}
        .expect 204
        .thru util.createUser()
        .post '/events/isinteractive', {
          app: 'app'
          isInteractive: false
          tags: {xx: 'x'}
        }
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
