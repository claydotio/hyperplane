Joi = require 'joi'

User = require './models/user'

accessToken = Joi.string()

id =  Joi.string().regex(
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/ # uuid
)

adminUser =
  id: User.ADMIN.id
  username: User.ADMIN.username

user =
  id: id

module.exports = {
  id: id
  user
  adminUser
  accessToken
}
