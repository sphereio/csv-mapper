Q = require 'q'
csv = require 'csv'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ValueTransformer
  @create: (options) -> util.abstractMethod() # promise with transformer
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  transform: (value) -> util.abstractMethod() # transformed value

class ConstantTransformer extends ValueTransformer
  @create: (options) ->
    Q(new ConstantTransformer(options))

  @supports: (options) ->
    options.type is 'constant'

  constructor: (options) ->
    @_value = options.value

  transform: (value) ->
    @_value

class UpperCaseTransformer extends ValueTransformer
  @create: (options) ->
    Q(new UpperCaseTransformer(options))

  @supports: (options) ->
    options.type is 'upper'

  constructor: (options) ->

  transform: (value) ->
    value.toUpperCase()

class LowerCaseTransformer extends ValueTransformer
  @create: (options) ->
    Q(new LowerCaseTransformer(options))

  @supports: (options) ->
    options.type is 'lower'

  constructor: (options) ->

  transform: (value) ->
    value.toLowerCase()

class RandomTransformer extends ValueTransformer
  @create: (options) ->
    Q(new RandomTransformer(options))

  @supports: (options) ->
    options.type is 'random'

  constructor: (options) ->
    @_size = options.size
    @_chars = options.chars

  transform: (value) ->
    rndChars = _.map _.range(@_size), (idx) =>
      @_chars.charAt _.random(0, @_chars.length - 1)

    rndChars.join ''

class RegexpTransformer extends ValueTransformer
  @create: (options) ->
    Q(new RegexpTransformer(options))

  @supports: (options) ->
    options.type is 'regexp'

  constructor: (options) ->
    @_find = new RegExp(options.find, 'g')
    @_replace = options.replace

  transform: (value) ->
    value.replace @_find, @_replace

class LookupTransformer extends ValueTransformer
  @create: (options) ->
    (new LookupTransformer(options))._init()

  @supports: (options) ->
    options.type is 'lookup'

  constructor: (options) ->
    @_header = options.header
    @_keyCol = options.keyCol
    @_valueCol = options.valueCol
    @_file = options.file
    @_csvDelimiter = options.csvDelimiter or ','
    @_csvQuote = options.csvQuote or '"'

    if options.values
      @_headers = options.values.shift()
      @_values = options.values

  _init: () ->
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

    cvsOptions =
      delimiter: @_csvDelimiter
      quote: @_csvQuote

    csv()
    .from("#{csvText}", cvsOptions)
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

module.exports =
  ValueTransformer: ValueTransformer
  ConstantTransformer: ConstantTransformer
  UpperCaseTransformer: UpperCaseTransformer
  LowerCaseTransformer: LowerCaseTransformer
  RandomTransformer: RandomTransformer
  RegexpTransformer: RegexpTransformer
  LookupTransformer: LookupTransformer
  defaultTransformers: [
    ConstantTransformer,
    UpperCaseTransformer,
    LowerCaseTransformer,
    RandomTransformer,
    RegexpTransformer,
    LookupTransformer
  ]
