_ = require 'lodash'

config = require '../../config'

loginAdmin = ->
  return (flare) ->
    flare
      .as 'nobody'
      .post '/users', {},
        {
          auth:
            username: 'admin'
            password: config.ADMIN_PASSWORD
        }
      .stash 'admin'
      .actor 'admin', {
        headers:
          'Authorization': 'Token :admin.accessToken'
      }
      .as 'admin'

createUser = (body) ->
  return (flare) ->
    flare
      .as 'nobody'
      .post '/users', _.merge {app: 'app'}, body
      .stash 'user'
      .actor 'user', {
        headers:
          'Authorization': 'Token :user.accessToken'
      }
      .as 'user'

exCreateUser = (body) ->
  return (flare) ->
    flare
      .as 'nobody'
      .exoid 'auth.login', _.merge {app: 'app'}, body
      .stash 'auth'
      .actor 'user',
        qs:
          accessToken: ':auth.accessToken'
      .as 'user'
      .exoid 'users.getMe'
      .stash 'user'

module.exports = {
  loginAdmin
  createUser
  exCreateUser
}
