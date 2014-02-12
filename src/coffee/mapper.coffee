Q = require 'q'
csv = require 'csv'
fs = require 'fs'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ColumnMapping
  init: (options) -> util.abstractMethod() # promise with this
  map: (origRow, accRow) -> util.abstractMethod() # mapped row promice
  columnName: () -> util.abstractMethod() # string
  priority: () -> util.abstractMethod() # int

  _initValueTransformers: (transformers, transformerConfig) ->
    if transformerConfig
      promises = _.map transformerConfig, (config) ->
        found  = _.find transformers, (t) -> t.supports(config)

        if found
          found.create config
        else
          throw new Error("unsupported value transformer type: #{config}")

      Q.all promises
    else
      Q([])

  _transformValue: (valueTransformers, value) ->
    safeValue = if util.nonEmpty(value) then value else ''
    _.reduce valueTransformers, ((acc, transformer) -> transformer.transform(acc)), safeValue

class ColumnTransformer extends ColumnMapping
  constructor: (options) ->
    @_transformers = options.transformers

  init: (options) ->
    @_fromCol = options.fromCol
    @_toCol = options.toCol
    @_priority = options.priority

    @_initValueTransformers @_transformers, options.valueTransformers
    .then (vt) =>
      @_valueTransformers = vt
      this

  map: (origRow, accRow) ->
    value = if accRow[@_fromCol] then accRow[@_fromCol] else origRow[@_fromCol]

    try
      accRow[@_toCol] = @_transformValue(@_valueTransformers, value)
    catch error
      throw new Error("Error during mapping from column '#{@_fromCol}' to column '#{@_toCol}' with current value '#{value}': #{error.message}")

    Q(accRow)

  columnName: () ->
    @_toCol

  priority: () ->
    @_priority or 2000

class ColumnGenerator extends ColumnMapping
  constructor: (options) ->
    @_transformers = options.transformers

  init: (options) ->
    @_toCol = options.toCol
    @_projectUnique = options.projectUnique
    @_synonymAttribute = options.synonymAttribute
    @_parts = _.clone options.parts
    @_priority = options.priority

    promises = _.map @_parts, (part) =>
      @_initValueTransformers @_transformers, part.valueTransformers
      .then (vt) ->
        part.valueTransformers = vt
        part

    Q.all promises
    .then (parts) =>
      this

  map: (origRow, accRow) ->
    partialValues = _.map @_parts, (part, idx) =>
      {size, pad, fromCol, valueTransformers} = part

      value = if accRow[fromCol] then accRow[fromCol] else origRow[fromCol]

      transformed = try
        @_transformValue(valueTransformers, value)
      catch error
        throw new Error("Error during mapping from column '#{fromCol}' to a generated column '#{@_toCol}' (part #{idx}) with current value '#{value}': #{error.message}")

      if transformed.length < size and pad
        _s.pad(transformed, size, pad)
      else if transformed.length is size
        transformed
      else
        throw new Error("Generated column part size (#{transformed.length} - '#{transformed}') is smaller than expected size (#{size}) and no padding is defined for this column. Source column '#{fromCol}', generated column '#{@_toCol}' (part #{idx}) with current value '#{value}'.")

    finalValue = partialValues.join ''

    # TODO: check @_synonymAttribute and @_projectUnique in SPHERE project!

    accRow[@_toCol] = finalValue

    Q(accRow)

  columnName: () ->
    @_toCol

  priority: () ->
    @_priority or 3000

###
  Transforms one object into another object accoring to the mapping configuration

  Options:
    mappingFile
    transformers
###
class Mapping
  constructor: (@_options = {}) ->

  init: () ->
    util.loadFile @_options.mappingFile
    .then (contents) =>
      @_constructMapping(JSON.parse(contents))
    .then (mapping) =>
      @_columnMapping = mapping
      this

  _constructMapping: (mappingJson) ->
    columnPromises = _.map mappingJson.columnMapping, (elem) =>
      c = switch elem.type
        when 'columnTransformer'
          new ColumnTransformer({transformers: @_options.transformers})
        when 'columnGenerator'
          new ColumnGenerator({transformers: @_options.transformers})
        else
          throw new Error("Unknown solumn mapping type: #{elem.type}")

      c.init elem

    Q.all columnPromises

  transformHeader: (columnNames) ->
    _.map @_columnMapping, (mapping) ->
      mapping.columnName()

  transformRow: (row) ->
    mappingsSorted = _.sortBy @_columnMapping, (mapping) -> mapping.priority()

    _.reduce mappingsSorted, ((accRowPromise, mapping) -> accRowPromise.then((accRow) -> mapping.map(row, accRow))), Q({})

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
exports.Mapping = Mapping
