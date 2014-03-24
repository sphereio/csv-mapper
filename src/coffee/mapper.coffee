Q = require 'q'
Rx = require 'rx'
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

  processCsv: (csvIn, outWriters) ->
    d = Q.defer()

    writers = _.map outWriters, (w) ->
      w.headers = null
      w.newHeaders = null
      w

    requiredGroups = _.map writers, (w) -> w.group
    buffers = {}
    headers = null
    lastBufferGroupValue = null

    csv()
    .from.stream(csvIn, @_cvsOptions())
    .transform (row, idx, done) =>
      if idx is 0 and @_includesHeaderRow
        headers = row
        newHeadersPerGroup = @_mapping.transformHeader requiredGroups, row

        _.each writers, (w) ->
          w.newHeaders = _.find(newHeadersPerGroup, (h) -> h.group is w.group).newHeaders
          w.writer.write w.newHeaders

        done null, []
      else
        if idx is 0
          headers = _.map _.range(row.length), (idx) -> "#{idx}"
          newHeadersPerGroup = @_mapping.transformHeader requiredGroups, headers

          _.each writers, (w) ->
            w.newHeaders = _.find(newHeadersPerGroup, (h) -> h.group is w.group).newHeaders

        inObj = @_convertToObject(headers, row)
        groupValue = if @_mapping.groupColumn? then inObj[@_mapping.groupColumn] else "#{idx}"
        buffer = buffers[groupValue]

        lastControlPromise =
          if not buffer?
            buffer = new GroupBuffer()
            buffers[groupValue] = buffer

            if lastBufferGroupValue?
              buffers[lastBufferGroupValue].finished()
              delete buffers[lastBufferGroupValue]
            else
              Q(false)
          else
            Q(false)

        [rowPromise, rowFinishedDefer, controlPromise] = buffer.add idx, (groupRows) =>
          bufferFirstIdx = buffer.getFirstIndex() or idx

          @_mapping.transformRow requiredGroups, inObj,
            index: if @_includesHeaderRow then idx - 1 else idx
            groupFirstIndex: if @_includesHeaderRow then bufferFirstIdx - 1 else bufferFirstIdx
            groupContext: buffer.getContext()
            groupRows: groupRows

        rowPromise
        .then (convertedPerGroup) =>
          _.each writers, (w) =>
            result = @_convertFromObject(w.newHeaders, _.find(convertedPerGroup, (c) -> c.group is w.group).row)
            w.writer.write result

          rowFinishedDefer.resolve true
        .fail (error) ->
          done error, null
          rowFinishedDefer.reject error
        .done()

        Q.all [controlPromise, lastControlPromise]
        .then ->
          done null, []
        .fail (error) ->
          done error, null
        .done()

        lastBufferGroupValue = groupValue
    .on 'end', (count) ->
      p =
        if lastBufferGroupValue?
          buffers[lastBufferGroupValue].finished()
        else
          Q(false)

      p
      .then ->
        d.resolve count
      .fail (error) ->
        d.reject error
      .done()
    .on 'error',
      (error) -> d.reject(error)

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
      stream = csvDef.stream or fs.createWriteStream(csvDef.file)
      writer = csv().to.stream(stream, @_cvsOptions())

      closeWriterFn = ->
        d = Q.defer()

        writer
        .on 'end', (count) -> d.resolve(count)
        .on 'error', (error) -> d.reject(error)
        .end()

        d.promise

      closeFn = ->
        if not csvDef.dontClose
          closeWriterFn()
          .finally ->
            util.closeStream(stream)

      {group: csvDef.group, writer: writer, close: closeFn}

  run: ->
    Q.spread [util.fileStreamOrStdin(@_inCsv), util.fileStreamOrStdout(@_outCsv)], ([csvIn, doNotCloseIn], [csvOut, doNotCloseStdOut]) =>
      mainWriters = @_createAdditionalWriters [{group: @_group, stream: csvOut, dontClose: doNotCloseStdOut}]
      additionalWriters = @_createAdditionalWriters @_additionalOutCsv
      allWriters = mainWriters.concat additionalWriters

      # strange, but error propagation does not wotk if the return value of the `finally` is returned
      @processCsv(csvIn, allWriters)
      .finally ->
        Q.all _.map(allWriters, (writer) -> writer.close())

class GroupBuffer
  constructor: ->
    @_buffer = {}
    @_context = {}
    @_finished
    @_written = false

  getContext: () ->
    @_context

  finished: () ->
    @_finished = true
    @_checkWhetherFinished()

  getFirstIndex: () ->
    @_firstIdx

  add: (idx, rowFn) ->
    d = Q.defer()
    dRowFinished = Q.defer()

    if not @_firstIdx?
      @_firstIdx = idx
      @_lastIdx = idx
    else if @_lastIdx < idx
      @_lastIdx = idx

    [d.promise, dRowFinished, @_incommingRow(idx, rowFn, d, dRowFinished.promise)]

  _incommingRow: (idx, rowFn, defer, rowFinishedPromise) ->
    @_buffer["#{idx}"] = {idx: idx, row: rowFn, defer: defer, rowFinishedPromise: rowFinishedPromise}

    @_checkWhetherFinished()

  _checkWhetherFinished: () ->
    if not @_written and @_finished and @_allRowsFinished()
      @_written = true

      ps = _.map @_getIdxs(), (idx) =>
        box = @_buffer["#{idx}"]

        box.row _.size(@_getIdxs())
        .then (res) ->
          [box, res]
        .fail (error) ->
          box.defer.reject error
          Q.reject error

      Q.all ps
      .then (list) ->
        writtenPs = _.map list, (elem) ->
          [box, row] = elem
          box.defer.resolve row
          box.rowFinishedPromise

        Q.all writtenPs
      .then ->
        true
    else
      Q(false)

  _allRowsFinished: () ->
    _.every @_getIdxs(), (idx) =>
      @_buffer["#{idx}"]?

  _getIdxs: () ->
    if @_firstIdx is @_lastIdx
      [@_firstIdx]
    else
      _.range(@_firstIdx, @_lastIdx + 1)
exports.Mapper = Mapper
