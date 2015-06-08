router = require 'promise-router'
HealthCtrl = require './controllers/health'

router.route 'get', '/healthcheck',
  HealthCtrl.check

router.route 'get', '/ping',
  HealthCtrl.ping

module.exports = router.getExpressRouter()
