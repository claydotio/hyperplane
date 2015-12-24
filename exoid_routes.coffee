router = require 'exoid-router'

UserCtrl = require './controllers/user'
EventCtrl = require './controllers/event'

authed = (handler) ->
  unless handler?
    return null

  (body, req, rest...) ->
    unless req.user?
      router.throw status: 401, detail: 'Unauthorized'

    handler body, req, rest...

module.exports = router
###################
# Public Routes   #
###################
.on 'auth.login', UserCtrl.login

###################
# Authed Routes   #
###################
.on 'users.getMe', authed UserCtrl.getMe
.on 'users.getExperimentsByApp', authed UserCtrl.exGetExperimentsByApp
.on 'users.updateMe', authed UserCtrl.updateMe

.on 'events.create', authed EventCtrl.exCreate
