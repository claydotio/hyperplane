Joi = require 'joi'

User = require './models/user'

MIN_SAFE_INTEGER = -9007199254740991
MAX_SAFE_INTEGER = 9007199254740991

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
  key: Joi.string().token()
  globalPercent: Joi.number()
  choices: Joi.array().items Joi.string().token()
  weights: Joi.array().optional().items Joi.number()

event =
  inviterId: id.optional()
  event: Joi.string().min(1).max(100).token() # Arbitrary min and max
  keys: Joi.array().items \
    Joi.string().min(1).max(100).token() # Arbitrary min and max
  strings: Joi.array().items \
    Joi.string().min(1).max(1000) # Arbitrary min and max
  # Floats are dissalowed currently because influx types are strict
  # and require decimals (e.g. 1.0 -> '1' would error)
  numbers: Joi.array().items \
    Joi.number().integer().min(MIN_SAFE_INTEGER).max(MAX_SAFE_INTEGER)

module.exports = {
  id: id
  user
  adminUser
  accessToken
  experiment
  event
}
