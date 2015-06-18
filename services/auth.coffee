jwt = require 'jsonwebtoken'
log = require 'loglevel'

router = require 'promise-router'
User = require '../models/user'

MAX_OAUTH_PARAMS = 20 # to avoid DOS (untested, unproven)

class AuthService
  # add user object as req.user
  middleware: (req, res, next) ->

    unless /^Basic ./.test req.header('Authorization')
      return next()

    b64Auth = req.header('Authorization')?.split(' ')[1]

    [username, password] = String(new Buffer(b64Auth, 'base64')).split(':')

    unless username
      return next()

    # Note that web crawlers may trigger account creation
    (if username and password
      User.fromUsernameAndPassword username, password
    else if username # accessToken
      User.fromAccessToken username
    )
    .then (user) ->
      if not user?
        next new router.Error status: 401, detail: 'Unauthorized'
      else
        # Authentication successful
        req.user = user
        next()
    .catch next


  assertAuthed: (req) ->
    unless req.user?
      throw new router.Error status: 401, detail: 'Unauthorized'

  assertAdmin: (req) ->
    unless req.user?.id is User.ADMIN.id
      throw new router.Error status: 403, detail: 'Forbidden'


module.exports = new AuthService()
