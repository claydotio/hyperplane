_ = require 'lodash'
Promise = require 'bluebird'
uuid = require 'node-uuid'
jwt = require 'jsonwebtoken'

r = require '../services/rethinkdb'
config = require '../config'

USERS_TABLE = 'users'

getTimeByHourInSeconds = ->
  Math.floor(Date.now() / 1000 / 60 / 60) * 60 *  60

defaultUser = (user) ->
  _.defaults user, {
    id: uuid.v4()
    joinTimeS: getTimeByHourInSeconds()
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
