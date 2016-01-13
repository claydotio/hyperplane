_ = require 'lodash'
log = require 'loga'

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
  PORT: env.HYPERPLANE_PORT or env.PORT or 50180
  ENV: env.NODE_ENV
  TIME_ZONE: env.TIME_ZONE or 'America/Los_Angeles'
  JWT_ISSUER: 'hyperplane'
  JWT_SECRET: env.HYPERPLANE_JWT_SECRET
  ADMIN_PASSWORD: env.HYPERPLANE_ADMIN_PASSWORD or 'insecurepassword'
  RETHINK:
    DB: env.HYPERPLANE_RETHINK_DB or 'hyperplane'
    HOST: env.RETHINK_HOST or 'localhost'
  INFLUX:
    DB: env.HYPERPLANE_INFLUX_DB or 'hyperplane'
    HOST: env.INFLUX_HOST or 'localhost'
    PORT: 8086
    RETENTION_DAYS: 16
  REDIS:
    PREFIX: env.HYPERPLANE_REDIS_PREFIX or 'hyperplane'
    HOST: env.REDIS_HOST or 'localhost'
    PORT: 6379
  ENVS:
    DEV: 'development'
    PROD: 'production'
    TEST: 'test'

assertNoneMissing config

module.exports = config
