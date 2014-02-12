Q = require 'q'
csv = require 'csv'
fs = require 'fs'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

###
  Transformes input CSV file to output CSV format by using the mappi mapping

  Options:
    inCsv - input CSV file (optional)
    outCsv - output CSV file (optional)
    includesHeaderRow - (optional - by default true)
    mapping
###
class Mapper
  _defaultOptions:
    includesHeaderRow: true

  constructor: (options = {}) ->
    @_options = _.extend {}, @_defaultOptions, options

  processCsv: (csvIn, csvOut, listeners = []) ->
    d = Q.defer()

    headers = null
    newHeaders = null

    c = csv().from.stream(csvIn).to.stream(csvOut)
    .transform (row, idx, done) =>
      if idx is 0 and @_options.includesHeaderRow
        headers = row
        newHeaders = @_options.mapping.transformHeader row
        done null, newHeaders
      else
        if idx is 0
          headers = _.map _.range(row.length), (idx) -> "#{idx}"

        @_options.mapping.transformRow @_convertToObject(headers, row)
        .then (converted) =>
          done null, @_convertFromObject(newHeaders, converted)
        .fail (error) ->
          done error, null
        .done()

    csvWithListenars = _.reduce(listeners, ((c, listen) -> c.on 'record', listen), c)

    csvWithListenars.on('end', (count) -> d.resolve(count)).on('error', (error) -> d.reject(error))

    d.promise

  _convertToObject: (properties, row) ->
    reduceFn = (acc, nameWithIdx) ->
      [name, idx] = nameWithIdx
      acc[name] = row[idx]
      acc

    _.reduce _.map(properties, ((prop, idx) -> [prop, idx])), reduceFn, {}

  _convertFromObject: (properties, obj) ->
    _.map properties, (name) -> obj[name]

  run: ->
    # TODO: introduce concept for the the second (additional) CSV file that stores retailer update info
    Q.spread [util.fileStreamOrStdin(@_options.inCsv), util.fileStreamOrStdout(@_options.outCsv)], (csvIn, csvOut) =>
      @processCsv(csvIn, csvOut)
      .finally () =>
        util.closeStream(csvOut) if util.nonEmpty @_options.outCsv

exports.Mapper = Mapper
