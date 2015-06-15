log = require 'loglevel'
nock = require 'nock'
Promise = require 'bluebird'
request = require 'clay-request'
_ = require 'lodash'

config = require 'config'
server = require 'index'
r = require 'services/rethinkdb'
InfluxService = require 'services/influxdb'

before ->
  nock.enableNetConnect()

  unless config.DEBUG
    log.disableAll()

  dropRethink = ->
    r.dbList()
    .contains config.RETHINK.DB
    .do (result) ->
      r.branch result,
        r.dbDrop(config.RETHINK.DB),
        {dopped: 0}
    .run()

  dropInflux = ->
    InfluxService.getDatabases()
    .then (databases) ->
      hasDatabase = _.includes databases, config.INFLUX.DB

      if hasDatabase
        InfluxService.dropDatabase(config.INFLUX.DB)

  Promise.all [
    dropRethink()
    dropInflux()
  ]
  .then ->
    Promise.all [
      server.rethinkSetup()
      server.influxSetup()
    ]
