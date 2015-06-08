_ = require 'lodash'
log = require 'loglevel'

env = process.env

assertNoneMissing = (object) ->
  getDeepUndefinedKeys = (object, prefix = '') ->
    _.reduce object, (missing, val, key) ->
      if val is undefined
        missing.concat prefix + key
      else if _.isPlainObject val
        missing.concat getDeepUndefinedKeys val, key + '.'
      else
        missing
    , []

  missing = getDeepUndefinedKeys(object)
  unless _.isEmpty missing
    throw new Error "Config missing values for: #{missing.join(', ')}"

config =
  DEBUG: if env.DEBUG then env.DEBUG is '1' else true
  PORT: env.API_PORT or env.PORT or 50010
  ENV: env.NODE_ENV
  ENVS:
    DEV: 'development'
    PROD: 'production'
    TEST: 'test'

assertNoneMissing config

module.exports = config
