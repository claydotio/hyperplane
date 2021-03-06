redis = require 'redis'
log = require 'loga'
Promise = require 'bluebird'

config = require '../config'

client = redis.createClient config.REDIS.PORT, config.REDIS.HOST

client.on 'error', log.error

module.exports = Promise.promisifyAll client
