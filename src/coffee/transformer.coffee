Q = require 'q'
csv = require 'csv'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ValueTransformer
  @create: (options) -> util.abstractMethod() # promise with transformer
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  transform: (value, row) -> util.abstractMethod() # transformed value promise

class ConstantTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new ConstantTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'constant'

  constructor: (transformers, options) ->
    @_value = options.value

  transform: (value, row) ->
    Q(@_value)

class PrintTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new PrintTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'print'

  constructor: (transformers, options) ->
    @_value = options.value

  transform: (value, row) ->
    console.info value
    Q(value)

class ColumnTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new ColumnTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'column'

  constructor: (transformers, options) ->
    @_col = options.col

  transform: (value, row) ->
    Q(row[@_col])

class RequiredTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new RequiredTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'required'

  constructor: (transformers, options) ->

  transform: (value, row) ->
    if util.nonEmpty(value)
      Q(value)
    else
      Q.reject new Error("Value is empty.")

class UpperCaseTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new UpperCaseTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'upper'

  constructor: (transformers, options) ->

  transform: (value, row) ->
    util.withSafeValue value, (safe) ->
      Q(safe.toUpperCase())

class LowerCaseTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new LowerCaseTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'lower'

  constructor: (transformers, options) ->

  transform: (value, row) ->
    util.withSafeValue value, (safe) ->
      Q(safe.toLowerCase())

class RandomTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new RandomTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'random'

  constructor: (transformers, options) ->
    @_size = options.size
    @_chars = options.chars

  transform: (value, row) ->
    rndChars = _.map _.range(@_size), (idx) =>
      @_chars.charAt _.random(0, @_chars.length - 1)

    Q(rndChars.join '')

class RegexpTransformer extends ValueTransformer
  @create: (transformers, options) ->
    Q(new RegexpTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'regexp'

  constructor: (transformers, options) ->
    @_find = new RegExp(options.find, 'g')
    @_replace = options.replace

  transform: (value, row) ->
    util.withSafeValue value, (safe) =>
      if safe.match @_find
        Q(safe.replace @_find, @_replace)
      else
        Q.reject(new Error("Regex #{@_find} does not match value '#{safe}'."))

class LookupTransformer extends ValueTransformer
  @create: (transformers, options) ->
    (new LookupTransformer(transformers, options))._init()

  @supports: (options) ->
    options.type is 'lookup'

  constructor: (transformers, options) ->
    @_header = options.header
    @_keyCol = options.keyCol
    @_valueCol = options.valueCol
    @_file = options.file
    @_csvDelimiter = options.csvDelimiter or ','
    @_csvQuote = options.csvQuote or '"'

    if options.values
      @_headers = options.values.shift()
      @_values = options.values

  _init: ->
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

  transform: (value, row) ->
    util.withSafeValue value, (safe) =>
      keyIdx = if _.isString @_keyCol then @_headers.indexOf(@_keyCol) else @_keyCol
      valueIdx = if _.isString @_valueCol then @_headers.indexOf(@_valueCol) else @_valueCol

      if keyIdx < 0 or valueIdx < 0
        throw new Error("Something is wrong in lookup config: key '#{@_keyCol}' or value '#{@_valueCol}' column not found by name!.")

      found = _.find @_values, (row) -> row[keyIdx] is safe

      if found
        Q(found[valueIdx])
      else
        fileMessage = if @_file then " File: #{@_file}." else ""
        valuesMessage = @_values.join "; "
        new Error("Lookup transformation failed for value '#{safe}'.#{fileMessage} Values: #{valuesMessage}")

class MultipartStringTransformer extends ValueTransformer
  @create: (transformers, options) ->
    new MultipartStringTransformer(transformers, options)._init()

  @supports: (options) ->
    options.type is 'multipartString'

  constructor: (transformers, options) ->
    @_transformers = transformers
    @_parts = _.clone options.parts

  _init: ->
    promises = _.map @_parts, (part) =>
      util.initValueTransformers @_transformers, part.valueTransformers
      .then (vt) ->
        part.valueTransformers = vt
        part

    Q.all promises
    .then (parts) =>
      this

  transform: (value, row) ->
    partialValuePromises = _.map @_parts, (part, idx) ->
      {size, pad, fromCol, valueTransformers} = part

      value = row[fromCol]

      util.transformValue(valueTransformers, value, row)
      .then (transformed) ->
        if transformed.length < size and pad
          _s.pad(transformed, size, pad)
        else if transformed.length is size
          transformed
        else
          valueMessage = if value then " with current value '#{value}'" else ""
          throw new Error("Generated column part size (#{transformed.length} - '#{transformed}') is smaller than expected size (#{size}) and no padding is defined for this column. Source column '#{fromCol}' (part #{idx})#{valueMessage}.")

    Q.all partialValuePromises
    .then (partialValues) ->
      partialValues.join ''

class FallbackTransformer extends ValueTransformer
  @create: (transformers, options) ->
    (new FallbackTransformer(transformers, options))._init()

  @supports: (options) ->
    options.type is 'fallback'

  constructor: (transformers, options) ->
    @_transformers = transformers
    @_valueTransformersConfig = options.valueTransformers

  _init: ->
    util.initValueTransformers @_transformers, @_valueTransformersConfig
    .then (vt) =>
      @_valueTransformers = vt
      this

  transform: (value, row) ->
    util.transformFirstValue(@_valueTransformers, value, row)

class AdditionalOptionsWrapper
  constructor: (@_delegate, @_options) ->

  _fullOptions: (options) ->
    _.extend {}, options, @_options

  create: (transformers, options) ->
    @_delegate.create(transformers, @_fullOptions(options))

  supports: (options) ->
    @_delegate.supports(@_fullOptions(options))

module.exports =
  ValueTransformer: ValueTransformer
  ConstantTransformer: ConstantTransformer
  PrintTransformer: PrintTransformer
  ColumnTransformer: ColumnTransformer
  RequiredTransformer: RequiredTransformer
  UpperCaseTransformer: UpperCaseTransformer
  LowerCaseTransformer: LowerCaseTransformer
  RandomTransformer: RandomTransformer
  RegexpTransformer: RegexpTransformer
  LookupTransformer: LookupTransformer
  MultipartStringTransformer: MultipartStringTransformer
  AdditionalOptionsWrapper: AdditionalOptionsWrapper
  FallbackTransformer: FallbackTransformer
  defaultTransformers: [
    ConstantTransformer,
    PrintTransformer,
    ColumnTransformer,
    RequiredTransformer,
    UpperCaseTransformer,
    LowerCaseTransformer,
    RandomTransformer,
    RegexpTransformer,
    LookupTransformer,
    MultipartStringTransformer,
    FallbackTransformer
  ]