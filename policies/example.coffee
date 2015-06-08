Joi = require 'joi'

router = require 'promise-router'

class ExamplePolicy
  assertExists: (shouldExist) ->
    unless shouldExist
      throw new router.Error status: 404, detail: 'User not found'

module.exports = new ExamplePolicy()
