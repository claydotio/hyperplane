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

createUser = ->
  return (flare) ->
    flare
      .as 'nobody'
      .post '/users'
      .stash 'user'
      .actor 'user', {
        headers:
          'Authorization': 'Token :user.accessToken'
      }
      .as 'user'

module.exports = {
  loginAdmin
  createUser
}
