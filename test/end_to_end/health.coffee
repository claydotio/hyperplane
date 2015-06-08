Flare = require 'flare-gun'

server = require '../../index'
flare = new Flare().express(server)

describe 'Health Check Routes', ->
  describe 'GET /healthcheck', ->
    it 'returns healthy', ->
      flare
        .get '/healthcheck'
        .expect 200,
          healthy: true

  describe 'GET /ping', ->
    it 'pongs', ->
      flare
        .get '/ping'
        .expect 200, 'pong'
