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
    group - the group of the main CSV
    additionalOutCsv
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

    @_group = options.group or util.defaultGroup()
    @_additionalOutCsv = options.additionalOutCsv

    if @_group is util.virtualGroup() or _.find(@_additionalOutCsv, (c) -> c.group is util.virtualGroup())
      throw new Error("You are not allowed to use vitual group for CSV creation. It's meant to be used within mapping itself.")

  processCsv: (csvIn, csvOut, additionalWriters) ->
    d = Q.defer()

    # TODO: Cleanup this mess

    writers = _.map additionalWriters, (w) ->
      w.headers = null
      w.newHeaders = null
      w

    writers.unshift
      group: @_group
      writer: null
      headers: null
      newHeaders: null

    requiredGroups = _.map writers, (w) -> w.group

    headers = null

    csv()
    .from.stream(csvIn, @_cvsOptions())
    .to.stream(csvOut, @_cvsOptions())
    .transform (row, idx, done) =>
      if idx is 0 and @_includesHeaderRow
        headers = row
        newHeadersPerGroup = @_mapping.transformHeader requiredGroups, row
        toReport = null

        _.each writers, (w) ->
          w.newHeaders = _.find(newHeadersPerGroup, (h) -> h.group is w.group).newHeaders

          if w.writer
            w.writer.write w.newHeaders
          else
            toReport = w.newHeaders

        done null, toReport
      else
        if idx is 0
          headers = _.map _.range(row.length), (idx) -> "#{idx}"
          newHeadersPerGroup = @_mapping.transformHeader requiredGroups, headers

          _.each writers, (w) ->
            w.newHeaders = _.find(newHeadersPerGroup, (h) -> h.group is w.group).newHeaders

        @_mapping.transformRow requiredGroups, @_convertToObject(headers, row)
        .then (convertedPerGroup) =>
          toReport = null

          _.each writers, (w) =>
            result = @_convertFromObject(w.newHeaders, _.find(convertedPerGroup, (c) -> c.group is w.group).row)

            if w.writer
              w.writer.write result
            else
              toReport = result

          done null, toReport
        .fail (error) ->
          done error, null
        .done()
    .on('end', (count) -> d.resolve(count))
    .on('error', (error) -> d.reject(error))

    d.promise

  _cvsOptions: ->
    delimiter: @_csvDelimiter
    quote: @_csvQuote

  _convertToObject: (properties, row) ->
    reduceFn = (acc, nameWithIdx) ->
      [name, idx] = nameWithIdx
      acc[name] = row[idx]
      acc

    _.reduce _.map(properties, ((prop, idx) -> [prop, idx])), reduceFn, {}

  _convertFromObject: (properties, obj) ->
    _.map properties, (name) -> obj[name]

  _createAdditionalWriters: (csvDefs) ->
    _.map csvDefs, (csvDef) =>
      stream = fs.createWriteStream(csvDef.file)
      writer = csv().to.stream(stream, @_cvsOptions())

      closeWriterFn = ->
        d = Q.defer()

        writer
        .on 'end', (count) -> d.resolve(count)
        .on 'error', (error) -> d.reject(error)
        .end()

        d.promise

      closeFn = ->
        closeWriterFn()
        .finally ->
          util.closeStream(stream)

      {group: csvDef.group, writer: writer, close: closeFn}

  run: ->
    Q.spread [util.fileStreamOrStdin(@_inCsv), util.fileStreamOrStdout(@_outCsv)], (csvIn, csvOut) =>
      additionalWriters = @_createAdditionalWriters @_additionalOutCsv

      # strange, but error propagation does not wotk if the return value of the `finally` is returned
      @processCsv(csvIn, csvOut, additionalWriters)
      .finally =>
        promises = _.map additionalWriters, (writer) -> writer.close()
        promises.push(util.closeStream(csvOut)) if util.nonEmpty @_outCsv

        Q.all promises



exports.Mapper = Mapper
