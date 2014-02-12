Q = require 'q'
csv = require 'csv'
fs = require 'fs'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ValueTransformer
  init: (options) -> util.abstractMethod() # promise with this
  transform: (value) -> util.abstractMethod() # transformed value

class ConstantTransformer extends ValueTransformer
  init: (options) ->
    @_value = options.value
    Q(this)

  transform: (value) ->
    @_value

class UpperCaseTransformer extends ValueTransformer
  init: (options) ->
    Q(this)

  transform: (value) ->
    value.toUpperCase()

class LowerCaseTransformer extends ValueTransformer
  init: (options) ->
    Q(this)

  transform: (value) ->
    value.toLowerCase()

class RandomTransformer extends ValueTransformer
  init: (options) ->
    @_size = options.size
    @_chars = options.chars
    Q(this)

  transform: (value) ->
    rndChars = _.map _.range(@_size), (idx) =>
      @_chars.charAt _.random(0, @_chars.length - 1)

    rndChars.join ''

class RegexpTransformer extends ValueTransformer
  init: (options) ->
    @_find = new RegExp(options.find, 'g')
    @_replace = options.replace
    Q(this)

  transform: (value) ->
    value.replace @_find, @_replace

class LookupTransformer extends ValueTransformer
  init: (options) ->
    @_header = options.header
    @_keyCol = options.keyCol
    @_valueCol = options.valueCol
    @_file = options.file

    if options.values
      @_headers = options.values.shift()
      @_values = options.values

    if (util.nonEmpty @_file)
      util.loadFile @_file
      .then (contents) =>
        @_parseCsv contents
      .then (values) =>
        @_headers = values.headers
        @_values = values.data
        this
    else
      Q(this)

  _parseCsv: (csvText) ->
    d = Q.defer()

    csv()
    .from("#{csvText}")
    .to.array (data) =>
      d.resolve
        headers: if @_header then data.shift() else []
        data: data
    .on 'error', (error) ->
      d.reject error

    d.promise

  transform: (value) ->
    keyIdx = if _.isString @_keyCol then @_headers.indexOf(@_keyCol) else @_keyCol
    valueIdx = if _.isString @_valueCol then @_headers.indexOf(@_valueCol) else @_valueCol

    if keyIdx < 0 or valueIdx < 0
      throw new Error("Something is wrong in lookup config: key '#{@_keyCol}' or value '#{@_valueCol}' column not found by name!.")

    found = _.find @_values, (row) -> row[keyIdx] is value

    if found
      found[valueIdx]
    else
      fileMessage = if @_file then "File: #{@_file}." else ""
      valuesMessage = @_values.join "; "
      throw new Error("Unfortunately, lookup transformation failed for value '#{value}'.#{fileMessage} Values: #{valuesMessage}")

class ColumnMapping
  init: (options) -> util.abstractMethod() # promise with this
  map: (origRow, accRow) -> util.abstractMethod() # mapped row promice
  columnName: () -> util.abstractMethod() # string
  priority: () -> util.abstractMethod() # int

  _initValueTransformers: (transformers) ->
    if transformers
      promises = _.map transformers, (t) ->
        transformer =
          switch t.type
            when 'constant'
              new ConstantTransformer()
            when 'upper'
              new UpperCaseTransformer()
            when 'lower'
              new LowerCaseTransformer()
            when 'random'
              new RandomTransformer()
            when 'regexp'
              new RegexpTransformer()
            when 'lookup'
              new LookupTransformer()
            else
              throw new Error("Unknown transformaer type: #{t.type}")

        transformer.init t

      Q.all promises
    else
      Q([])

  _transformValue: (valueTransformers, value) ->
    safeValue = if util.nonEmpty(value) then value else ''
    _.reduce valueTransformers, ((acc, transformer) -> transformer.transform(acc)), safeValue

class ColumnTransformer extends ColumnMapping
  init: (options) ->
    @_fromCol = options.fromCol
    @_toCol = options.toCol
    @_priority = options.priority

    @_initValueTransformers options.valueTransformers
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
  init: (options) ->
    @_toCol = options.toCol
    @_projectUnique = options.projectUnique
    @_synonymAttribute = options.synonymAttribute
    @_parts = _.clone options.parts
    @_priority = options.priority

    promises = _.map @_parts, (part) =>
      @_initValueTransformers part.valueTransformers
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
    columnPromises = _.map mappingJson.columnMapping, (elem) ->
      c = switch elem.type
        when 'columnTransformer'
          new ColumnTransformer()
        when 'columnGenerator'
          new ColumnGenerator()
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
