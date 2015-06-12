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

module.exports = {
  loginAdmin
}
