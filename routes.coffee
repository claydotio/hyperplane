router = require 'promise-router'

AuthService = require './services/auth'
HealthCtrl = require './controllers/health'
UserCtrl = require './controllers/user'

# Require authentication by default
route = (verb, path, handlers...) ->
  authedHandlers = [AuthService.assertAuthed].concat handlers
  router.route verb, path, authedHandlers...

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

###################
# Private Routes  #
###################

module.exports = router.getExpressRouter()
