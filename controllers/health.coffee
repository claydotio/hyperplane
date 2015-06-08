class HealthCtrl
  check: ->
    return {healthy: true}

  ping: -> 'pong'

module.exports = new HealthCtrl()
