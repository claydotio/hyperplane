cors = require 'cors'
express = require 'express'
bodyParser = require 'body-parser'
log = require 'loga'
fs = require 'fs'
Promise = require 'bluebird'
_ = require 'lodash'

config = require './config'
routes = require './routes'
exoidRoutes = require './exoid_routes'
AuthService = require './services/auth'
r = require './services/rethinkdb'
InfluxService = require './services/influxdb'

# Setup rethinkdb
createDatabaseIfNotExist = (dbName) ->
  r.dbList()
  .contains dbName
  .do (result) ->
    r.branch result,
      {created: 0},
      r.dbCreate dbName
  .run()

createTableIfNotExist = (tableName) ->
  r.tableList()
  .contains tableName
  .do (result) ->
    r.branch result,
      {created: 0},
      r.tableCreate tableName
  .run()

createIndexIfNotExist = (tableName, indexName, indexFn, indexOpts) ->
  r.table tableName
  .indexList()
  .contains indexName
  .do (result) ->
    r.branch result,
      {created: 0},
      if indexFn
        r.table(tableName).indexCreate indexName, indexFn, indexOpts
      else
        r.table(tableName).indexCreate indexName, indexOpts
  .run()

rethinkSetup = ->
  createDatabaseIfNotExist config.RETHINK.DB
  .then ->
    Promise.map fs.readdirSync('./models'), (modelFile) ->
      model = require('./models/' + modelFile)
      tables = model?.RETHINK_TABLES

      unless tables
        return

      Promise.map tables, (table) ->
        createTableIfNotExist table.NAME
        .then ->
          Promise.map (table.INDEXES or []), (index) ->
            if _.isString index
              indexName = index
              indexOpts = {}
              indexFn = null
            else
              indexName = index.name
              indexOpts = {multi: index.multi}
              indexFn = index.fn
            createIndexIfNotExist table.NAME, indexName, indexFn, indexOpts

influxSetup = ->
  InfluxService.getDatabases()
  .then (databases) ->
    unless _.includes databases, config.INFLUX.DB
      InfluxService.createDatabase config.INFLUX.DB
  .then ->
    InfluxService.alterRetentionPolicyDuration config.INFLUX.DB, 'default',
      config.INFLUX.RETENTION_DAYS

app = express()

app.set 'x-powered-by', false

app.use cors()
app.use bodyParser.json({limit: '1mb'})
# Avoid CORS preflight
app.use bodyParser.json({type: 'text/plain', limit: '1mb'})
app.use AuthService.middleware
app.post '/exoid', exoidRoutes.asMiddleware()
app.use routes

module.exports = {
  app
  rethinkSetup
  influxSetup
}
