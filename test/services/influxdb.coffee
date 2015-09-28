zock = require 'zock'
b = require 'b-assert'

config = require '../../config'
InfluxService = require '../../services/influxdb'

describe 'InfluxService', ->
  it 'writes properly escaped lines', ->
    zock
    .base "http://#{config.INFLUX.HOST}:#{config.INFLUX.PORT}"
    .post '/write'
    .reply ({body}) ->
      b body.trim(), '''
        measurement,tag=\\,_\\=_\\ _\\ _'_\\"_\\\\ \
        field="\\,_\\=_\\ _\\ _'_\\"_\\\\"
      '''
    .withOverrides ->
      InfluxService.write(
        'measurement',
        {tag: ',_=_ _\n_\'_\"_\\'},
        {field: ',_=_ _\n_\'_\"_\\'}
      )
