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
    csvDelimiter - (optional - by default `,`)
    csvQuote - (optional - by default `"`)
###
class Mapper
  _defaultOptions:
    includesHeaderRow: true

  constructor: (options = {}) ->
    @_inCsv = options.inCsv
    @_outCsv = options.outCsv

    @_csvDelimiter = options.csvDelimiter or ','
    @_csvQuote = options.csvQuote or '"'

    @_includesHeaderRow = options.includesHeaderRow or true
    @_mapping = options.mapping

  processCsv: (csvIn, csvOut, listeners = []) ->
    d = Q.defer()

    headers = null
    newHeaders = null

    cvsOptions =
      delimiter: @_csvDelimiter
      quote: @_csvQuote

    c = csv()
    .from.stream(csvIn, cvsOptions)
    .to.stream(csvOut, cvsOptions)
    .transform (row, idx, done) =>
      if idx is 0 and @_includesHeaderRow
        headers = row
        newHeaders = @_mapping.transformHeader row
        done null, newHeaders
      else
        if idx is 0
          headers = _.map _.range(row.length), (idx) -> "#{idx}"

        @_mapping.transformRow @_convertToObject(headers, row)
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
    Q.spread [util.fileStreamOrStdin(@_inCsv), util.fileStreamOrStdout(@_outCsv)], (csvIn, csvOut) =>
      @processCsv(csvIn, csvOut)
      .finally () =>
        util.closeStream(csvOut) if util.nonEmpty @_outCsv

exports.Mapper = Mapper
