moment = require 'moment-timezone'

MS_IN_HOUR = 1000 * 60 * 60
MS_IN_DAY = MS_IN_HOUR * 24

getTimeZoneOffsetMS = (timeZone, date) ->
  moment.tz.zone(timeZone).parse(date) * 60 * 1000

module.exports =
  dateToDay: (date, timeZone) ->
    offset = getTimeZoneOffsetMS(timeZone, date)
    Math.floor((date - offset) / MS_IN_DAY)

  dateToHour: (date, timeZone) ->
    offset = getTimeZoneOffsetMS(timeZone, date)
    Math.floor((date - offset) / MS_IN_HOUR)
