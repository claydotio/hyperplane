_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'
jwt = require 'jsonwebtoken'
moment = require 'moment-timezone'

r = require '../services/rethinkdb'
config = require '../config'

USERS_TABLE = 'users'
MS_IN_DAY = 1000 * 60 * 60 * 24
SESSION_CYCLE_TIME_MS = 1000 * 60 * 30 # 30 min

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
  id = user?.id or uuid.v4()
  _.defaults user, {
    id: id
    joinDay: Math.floor(moment().tz(config.TIME_ZONE) / MS_IN_DAY)
    inviterJoinDay: null
    sessionId: uuid.v4()
    lastSessionEventTime: Date.now()
    lastSessionEventDelta: 0
    sessionEvents: 0
    experimentKey: id
  }

ADMIN = defaultUser {
  id: 'c2cc3b1b-4c6d-4837-93e3-b519d82080ca' # uuid v4
  username: 'admin'
  experimentKey: 'c2cc3b1b-4c6d-4837-93e3-b519d82080ca' # id
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

    if inactivity > SESSION_CYCLE_TIME_MS
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
      'experimentKey'
      'accessToken'
    ]

module.exports = new UserModel()
