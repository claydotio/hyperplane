server = require '../index'
flare = require('flare-gun').express(server.app)
Promise = require 'bluebird'
_ = require 'lodash'

config = require '../config'
r = require '../services/rethinkdb'
InfluxService = require '../services/influxdb'
util = require '../test/end_to_end/util'

MS_IN_DAY = 1000 * 60 * 60 * 24
SECONDS_TO_NS = 1000000 * 1000 # nanoseconds per second

dropRethink = ->
  r.dbList()
  .contains config.RETHINK.DB
  .do (result) ->
    r.branch result,
      r.dbDrop(config.RETHINK.DB),
      {dopped: 0}
  .run()

dropInflux = ->
  InfluxService.getDatabases()
  .then (databases) ->
    hasDatabase = _.includes databases, config.INFLUX.DB

    if hasDatabase
      InfluxService.dropDatabase(config.INFLUX.DB)

toNS = (milliseconds) ->
  new Date(parseInt(milliseconds)) * SECONDS_TO_NS

games = ['fruit-ninja', 'flappy-bird']

Promise.all [
  dropRethink()
  dropInflux()
]
.then ->
  Promise.all [
    server.rethinkSetup()
    server.influxSetup()
  ]
.then ->
  adminFlare = flare
    .thru util.loginAdmin()

  experiments = [
    {
      apps: ['fruit-ninja', 'flappy-bird']
      key: 'login_button'
      globalPercent: 100
      choices: ['control', 'blue']
    }
    {
      apps: ['flappy-bird']
      key: 'invite_landing'
      globalPercent: 100
      choices: ['control', 'purple', 'yellow']
    }
    {
      apps: ['flappy-bird']
      key: 'feedback'
      globalPercent: 10
      choices: ['control', 'visible']
    }
    {
      apps: ['fruit-ninja']
      key: 'share_icon'
      globalPercent: 100
      choices: ['control', 'big_red', 'big_blue', 'small_red', 'small_blue']
    }
    {
      apps: ['fruit-ninja']
      key: 'animation'
      globalPercent: 100
      choices: ['control', 'animated']
      weights: [0.2, 0.8]
    }
  ]

  Promise.each experiments, (experiment) ->
    adminFlare
      .post '/experiments', experiment
      .expect 200
# coffeelint: disable=cyclomatic_complexity
.then ->
  # for each app
  Promise.map games, (game) ->
    # 50 users
    Promise.map _.range(50), (index) ->
      daysToSimulate = 8
      activeDays = _.sample [1, 1, 1, 2, 3]
      joinDay = _.sample _.range(daysToSimulate)
      joinDate = new Date Date.now() - MS_IN_DAY * (daysToSimulate - joinDay)
      joinDayEpoch = String(
        Math.floor joinDate / 1000 / 60 / 60 / 24
      )
      inviterJoinDay = if Math.random() > 0.5
        String(parseInt(joinDayEpoch) - _.sample(_.range(1, 6)))
      else
        undefined
      userAgent = _.sample [
        'Mozilla/5.0 (Linux; Android 4.4.2;
                      Nexus 5 Build/KOT49H) AppleWebKit/537.36
                      (KHTML, like Gecko) Chrome/32.0.1700.99
                      Mobile Safari/537.36'
        'Mozilla/5.0 (iPhone; CPU iPhone OS 6_0
                      like Mac OS X) AppleWebKit/536.26
                      (KHTML, like Gecko) Version/6.0
                      Mobile/10A5376e Safari/8536.25'
        'Mozilla/5.0 (Linux; Android 5.0; pl-pl;
                      SAMSUNG SM-G900F/G900FXXU1BNL9
                      Build/LRX21T) AppleWebKit/537.36
                      (KHTML, like Gecko) Version/2.1
                      Chrome/34.0.1847.76 Mobile Safari/537.36'
        'Mozilla/5.0 (Linux; U; Android 4.0.4; en-gb; GT-I9300
                      Build/IMM76D) AppleWebKit/534.30 (KHTML,
                      like Gecko) Version/4.0 Mobile Safari/534.30'
        'Mozilla/5.0 (Linux; Android 5.0; ASUS_T00J Build/LRX21V)
                      AppleWebKit/537.36 (KHTML, like Gecko)
                      Chrome/38.0.2125.509 Mobile Safari/537.36'
      ]

      language = _.sample ['en-US', 'en', 'en-GB', 'fr']
      ip = '127.0.0.1'

      flare
        .thru util.createUser({
          app: game
          joinDay: joinDayEpoch
          inviterJoinDay
          # Avoid influxdb de-duplication by adding small value
          timestamp: String toNS(Math.floor(joinDate / 1000 + index))
        })
        .thru (flare) ->
          flare
            .get '/users/me/experiments/' + game
          .then ({res}) ->
            experiments = res.body
            Promise.each _.range(daysToSimulate), (day) ->
              timestamp = Math.floor(
                (Date.now() - MS_IN_DAY * (daysToSimulate - day)) / 1000
              )
              refererHost = _.sample [
                'google.com', 'clay.io', 'github.com', 'youtube.com', undefined
              ]

              events = ['view', 'pageview']

              if experiments['login_button'] is 'blue' and
                  Math.random() > 0.7
                events.push 'pageview'

              if Math.random() > 0.2
                events.push 'egp'

              if Math.random() > 0.1
                events.push 'send'

              if experiments['feedback'] is 'visible' and
                  Math.random() > 0.3
                events.push 'send'

              if Math.random() > 0.5
                events.push 'revenue'

              revenue = Math.floor Math.random() * 100
              if experiments['login_button'] is 'blue'
                revenue *= 2
              if experiments['animation'] is 'control'
                revenue *= 3

              if day >= joinDay and day < joinDay + activeDays
                flare
                  .thru (flare) ->
                    Promise.map events, (event, index) ->
                      flare
                      .post "/events/#{event}",
                        {
                          # Avoid influxdb de-duplication by adding small value
                          timestamp: String toNS(timestamp + index)
                          app: game
                          tags:
                            refererHost: refererHost
                          fields:
                            value: switch event
                              when 'revenue'
                                revenue
                              else undefined
                        }, {
                          headers:
                            'user-agent': userAgent
                            'accept-language': language
                            'x-forwards-for': ip
                        }
                      .expect 204
    , {concurrency: 100}
# coffeelint: enable=cyclomatic_complexity
.then ->
  console.log 'DONE!'
.catch (err) ->
  console.error err
