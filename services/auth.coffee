jwt = require 'jsonwebtoken'
log = require 'loglevel'

router = require 'promise-router'
User = require '../models/user'

MAX_OAUTH_PARAMS = 20 # to avoid DOS (untested, unproven)

class AuthService
  middleware: (req, res, next) ->
    # get access token and add user object as req.user
    # accessToken = req.query?.accessToken

    accessToken = null
    hdr = req.header('Authorization')

    accessToken = if hdr and hdr.match(/^OAuth\b/i)
      params = hdr.match(/[^=\s]+="[^"]*"(?:,\s*)?/g)
      if params.length > MAX_OAUTH_PARAMS
        null
      else
        i = 0
        parsed = {}
        while i < params.length
          match = params[i].match(/([^=\s]+)="([^"]*)"/)
          key = decodeURIComponent(match[1])
          value = decodeURIComponent(match[2])
          parsed[key] = value
          i += 1
        parsed['oauth_token']
    else
      null

    unless accessToken
      return next()

    # Note that web crawlers may trigger account creation

    User.fromAccessToken accessToken
    .then (user) ->
      # Authentication successful (unless user is null)
      req.user = user
    .catch (err) ->
      log.error err
    .then ->
      next()

  assertAuthed: (req) ->
    unless req.user?
      throw new router.Error status: 401, detail: 'Unauthorized'

  assertAdmin: (req) ->
    unless req.user?.id is User.ADMIN.id
      throw new router.Error status: 403, detail: 'Forbidden'


module.exports = new AuthService()
