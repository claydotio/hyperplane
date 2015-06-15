router = require 'promise-router'

AuthService = require './services/auth'
HealthCtrl = require './controllers/health'
UserCtrl = require './controllers/user'
ExperimentCtrl = require './controllers/experiment'
EventCtrl = require './controllers/event'

# Require authentication by default
route = (verb, path, handlers...) ->
  authedHandlers = [AuthService.assertAuthed].concat handlers
  router.route verb, path, authedHandlers...

routeAdmin = (verb, path, handlers...) ->
  authedHandlers = [AuthService.assertAdmin].concat handlers
  route verb, path, authedHandlers...

routePublic = router.route

###################
# Public Routes   #
###################

routePublic 'get', '/healthcheck',
  HealthCtrl.check

routePublic 'get', '/ping',
  HealthCtrl.ping

routePublic 'post', '/users',
  UserCtrl.loginOrCreate

#################
# Authed Routes #
#################

route 'post', '/events/:namespace',
  EventCtrl.create

###################
# Admin Routes    #
###################

routeAdmin 'get', '/events',
  EventCtrl.find

routeAdmin 'post', '/experiments',
  ExperimentCtrl.create

routeAdmin 'get', '/experiments',
  ExperimentCtrl.getAll

routeAdmin 'put', '/experiments/:id',
  ExperimentCtrl.update

module.exports = router.getExpressRouter()
