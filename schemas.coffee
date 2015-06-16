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

experiment =
  id: id
  namespace: Joi.string()
  key: Joi.string()
  globalPercent: Joi.number()
  choices: Joi.array().items Joi.string()
  weights: Joi.array().optional().items Joi.number()

event =
  namespace: Joi.string()
  fields:
    value: Joi.number()
  tags:
    event: Joi.string()
    refererHost: Joi.string().optional()

module.exports = {
  id: id
  user
  adminUser
  accessToken
  experiment
  event
}
