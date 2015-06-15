_ = require 'lodash'
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
