config = require '../../config'

loginAdmin = ->
  return (flare) ->
    flare
      .post '/users',
        {
          username: 'admin'
          password: config.ADMIN_PASSWORD
        }
      .stash 'admin'
      .actor 'admin', {
        oauth:
          token: ':admin.accessToken'
      }
      .as 'admin'

createUser = ->
  return (flare) ->
    flare
      .post '/users'
      .stash 'user'
      .actor 'user', {
        oauth:
          token: ':user.accessToken'
      }
      .as 'user'

module.exports = {
  loginAdmin
  createUser
}
