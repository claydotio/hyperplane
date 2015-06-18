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
        auth:
          username: ':admin.accessToken'
      }
      .as 'admin'

createUser = ->
  return (flare) ->
    flare
      .as 'nobody'
      .post '/users'
      .stash 'user'
      .actor 'user', {
        auth:
          username: ':user.accessToken'
      }
      .as 'user'

module.exports = {
  loginAdmin
  createUser
}
