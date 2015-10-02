jwt = require 'jsonwebtoken'
log = require 'loglevel'
Promise = require 'bluebird'

router = require 'promise-router'
User = require '../models/user'

class AuthService
  # add user object as req.user
  middleware: (req, res, next) ->
    authHeader = req.header('Authorization')
    if req.query?.accessToken?
      authHeader = "Token #{req.query.accessToken}"

    unless authHeader
      return next()

    [authScheme, authValue] = authHeader.split(' ')


    # Note that web crawlers may trigger account creation
    (switch authScheme
      when 'Basic'
        decoded = String(new Buffer(authValue, 'base64'))
        [username, password] = decoded.split(':')

        User.fromUsernameAndPassword username, password
      when 'Token'
        User.fromAccessToken authValue
      else
        Promise.resolve null
    ).then (user) ->
      if not user?
        next()
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
