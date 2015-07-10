_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'
jwt = require 'jsonwebtoken'

r = require '../services/rethinkdb'
config = require '../config'

USERS_TABLE = 'users'
MS_IN_DAY = 1000 * 60 * 60 * 24
SESSION_CYCLE_TIME_MS = 1000 * 60 * 30

constTimeEqual = (a, b) ->
  c = 0
  i = 0
  n = a.length
  while i < n
    c |= a[i] ^ b[i]
    i += 1
  c |= a.length ^ b.length

  return c is 0

defaultUser = (user) ->
  _.defaults user, {
    id: uuid.v4()
    joinDay: String Math.floor(Date.now() / 1000 / 60 / 60 / 24)
    inviterJoinDay: null
    sessionId: uuid.v4()
    lastSessionEventTime: Date.now()
    lastSessionEventDelta: 0
    sessionEvents: 0
  }

ADMIN = defaultUser {
  id: 'c2cc3b1b-4c6d-4837-93e3-b519d82080ca' # uuid v4
  username: 'admin'
}

generateAccessToken = (user) ->
  jwt.sign {
    userId: user.id
    scopes: ['*']
  }, config.JWT_SECRET, {
    issuer: config.JWT_ISSUER
    subject: user.id
  }

class UserModel
  RETHINK_TABLES: [
    {
      NAME: USERS_TABLE
    }
  ]
  ADMIN: ADMIN

  generateAccessToken: generateAccessToken

  fromAccessToken: (token) =>
    Promise.promisify(jwt.verify, jwt)(
      token,
      config.JWT_SECRET,
      {issuer: config.JWT_ISSUER}
    )
    .then (decoded) =>
      @getById decoded?.userId

  fromUsernameAndPassword: (username, password) =>
    if username is @ADMIN.username and
        constTimeEqual password, config.ADMIN_PASSWORD
      @getById @ADMIN.id
    else
      Promise.resolve null

  create: (user) ->
    user = defaultUser user

    r.table USERS_TABLE
    .insert user
    .run()
    .then ->
      user

  getById: (id) ->
    if id is ADMIN.id
      return Promise.resolve ADMIN

    r.table USERS_TABLE
    .get id
    .run()
    .then defaultUser

  updateById: (id, diff) ->
    r.table USERS_TABLE
    .get id
    .update diff
    .run()

  cycleSession: (user) =>
    {lastSessionEventTime} = user

    currentTime = Date.now()
    inactivity = currentTime - lastSessionEventTime
    lastDay = Math.floor lastSessionEventTime / MS_IN_DAY
    currentDay = Math.floor currentTime / MS_IN_DAY

    if inactivity > SESSION_CYCLE_TIME_MS or lastDay isnt currentDay
      update = {
        sessionId: uuid.v4()
        lastSessionEventTime: currentTime
        lastSessionEventDelta: 0
        sessionEvents: 0
      }
    else
      update = {
        lastSessionEventTime: currentTime
        lastSessionEventDelta: inactivity
        sessionEvents: user.sessionEvents + 1
      }

    @updateById user.id, update
    .then ->
      _.defaults update, user

  embed: _.curry (embed, user) ->
    embedded = _.merge {}, user

    for key in embed
      switch key
        when 'accessToken'
          embedded.accessToken = generateAccessToken user

    return Promise.props embedded

  sanitize: _.curry (requesterId, user) ->
    _.pick user, [
      'id'
      'username'
      'accessToken'
    ]

module.exports = new UserModel()
