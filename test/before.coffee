log = require 'loglevel'
nock = require 'nock'

config = require 'config'
server = require 'index'

DB = config.RETHINK.DB
HOST = config.RETHINK.HOST

r = require('rethinkdbdash')
  host: HOST
  db: DB

before ->
  nock.enableNetConnect('0.0.0.0')

  unless config.DEBUG
    log.disableAll()

  r.dbList()
  .contains DB
  .do (result) ->
    r.branch result,
      r.dbDrop(DB),
      {dopped: 0}
  .run()
  .then server.rethinkSetup
