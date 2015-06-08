cors = require 'cors'
express = require 'express'
bodyParser = require 'body-parser'
log = require 'loglevel'

routes = require './routes'

log.enableAll()

app = express()

app.set 'x-powered-by', false

app.use bodyParser.json()
app.use cors()
app.use routes

module.exports = app
