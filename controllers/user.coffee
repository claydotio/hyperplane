User = require '../models/user'
config = require '../config'

constTimeEqual = (a, b) ->
  c = 0
  i = 0
  n = a.length
  while i < n
    c |= a[i] ^ b[i]
    i += 1
  c |= a.length ^ b.length

  return c is 0

class UserCtrl
  loginOrCreate: (req) ->
    username = req.body?.username
    password = req.body?.password

    user = switch
      when username is User.ADMIN.username and
          constTimeEqual password, config.ADMIN_PASSWORD
        User.getById User.ADMIN.id
      when req.user?
        Promise.resolve req.user
      else
        User.create({})

    user.then User.embed ['accessToken']
    .then (user) ->
      User.sanitize(user.id, user)



module.exports = new UserCtrl()
