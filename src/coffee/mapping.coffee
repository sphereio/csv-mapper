Q = require 'q'
csv = require 'csv'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ColumnMapping
  @create: (options) -> util.abstractMethod() # promise with mapplig
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  constructor: (options) ->
    @_priority = options.priority
    @_groups = options.groups or [util.defaultGroup()]

  map: (origRow, accRow) -> util.abstractMethod() # mapped row promice
  transformHeader: (headerAccumulator, originalHeader) -> util.abstractMethod() # array of string with the new updated header
  _defaultPriority: () -> util.abstractMethod() # int

  priority: () ->
    @_priority or @_defaultPriority

  supportsGroup: (group) ->
    _.contains @_groups, group

  _initValueTransformers: (transformers, transformerConfig) ->
    if transformerConfig
      promises = _.map transformerConfig, (config) ->
        found  = _.find transformers, (t) -> t.supports(config)

        if found
          found.create config
        else
          throw new Error("unsupported value transformer type: #{config.type}")

      Q.all promises
    else
      Q([])

  _transformValue: (valueTransformers, value) ->
    safeValue = if util.nonEmpty(value) then value else ''
    _.reduce valueTransformers, ((acc, transformer) -> transformer.transform(acc)), safeValue

  _getPropertyForGroup: (origRow, accRow, name) ->
    found = _.find accRow, (acc) =>
      @supportsGroup(acc.group) and acc.row[name]

    if found
      found.row[name]
    else
      origRow[name]

  _updatePropertyInGroups: (accRow, name, value) ->
    _.each accRow, (acc) =>
      if @supportsGroup(acc.group)
        acc.row[name] = value

  _containsSupportedGroup: (accRow) ->
    _.find accRow, (acc) => @supportsGroup(acc.group)

class CopyFromOriginalTransformer extends ColumnMapping
  @create: (transformers, options) ->
    Q(new CopyFromOriginalTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'copyFromOriginal'

  constructor: (transformers, options) ->
    super(options)

    @_includeCols = options.includeCols
    @_excludeCols = options.excludeCols

  map: (origRow, accRow) ->
    reduceFn = (acc, name) =>
      _.each accRow, (acc) =>
        if @supportsGroup(acc.group) and @_include(name)
          acc.row[name] = origRow[name]

      acc

    Q(_.reduce(_.keys(origRow), reduceFn, accRow))

  _include: (name) ->
    (not @_includeCols or _.contains(@_includeCols, name)) and (not @_excludeCols or not _.contains(@_excludeCols, name))

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: acc.newHeaders.concat _.filter(originalHeader, ((name) => @_include(name)))}
      else
        acc

  priority: () ->
    @_priority or 1000

class RemoveColumnsTransformer extends ColumnMapping
  @create: (transformers, options) ->
    Q(new RemoveColumnsTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'removeColumns'

  constructor: (transformers, options) ->
    super(options)

    @_cols = options.cols or []

  map: (origRow, accRow) ->
    reduceFn = (acc, name) =>
      _.each accRow, (acc) =>
        if @supportsGroup(acc.group) and _.contains(@_cols, name)
          delete acc[name]

      acc

    Q(_.reduce(_.keys(accRow), reduceFn, accRow))

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: _.filter(acc.newHeaders, ((name) => not _.contains(@_cols, name)))}
      else
        acc

  priority: () ->
    @_priority or 1500

class ColumnTransformer extends ColumnMapping
  @create: (transformers, options) ->
    (new ColumnTransformer(transformers, options))._init()

  @supports: (options) ->
    options.type is 'columnTransformer'

  constructor: (transformers, options) ->
    super(options)

    @_transformers = transformers

    @_fromCol = options.fromCol
    @_toCol = options.toCol
    @_valueTransformersConfig = options.valueTransformers

  _init: () ->
    @_initValueTransformers @_transformers, @_valueTransformersConfig
    .then (vt) =>
      @_valueTransformers = vt
      this

  map: (origRow, accRow) ->
    value = @_getPropertyForGroup origRow, accRow, @_fromCol

    try
      if @_containsSupportedGroup(accRow)
        finalValue = @_transformValue(@_valueTransformers, value)
        @_updatePropertyInGroups(accRow, @_toCol, finalValue)
    catch error
      throw new Error("Error during mapping from column '#{@_fromCol}' to column '#{@_toCol}' with current value '#{value}': #{error.message}")

    Q(accRow)

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: acc.newHeaders.concat([@_toCol])}
      else
        acc

  priority: () ->
    @_priority or 2000

class ColumnGenerator extends ColumnMapping
  @create: (transformers, options) ->
    (new ColumnGenerator(transformers, options))._init()

  @supports: (options) ->
    options.type is 'columnGenerator'

  constructor: (transformers, options) ->
    super(options)

    @_transformers = transformers

    @_toCol = options.toCol
    @_projectUnique = options.projectUnique
    @_synonymAttribute = options.synonymAttribute
    @_parts = _.clone options.parts

  _init: () ->
    promises = _.map @_parts, (part) =>
      @_initValueTransformers @_transformers, part.valueTransformers
      .then (vt) ->
        part.valueTransformers = vt
        part

    Q.all promises
    .then (parts) =>
      this

  map: (origRow, accRow) ->
    if @_containsSupportedGroup(accRow)
      partialValues = _.map @_parts, (part, idx) =>
        {size, pad, fromCol, valueTransformers} = part

        value = @_getPropertyForGroup origRow, accRow, fromCol

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

      @_updatePropertyInGroups(accRow, @_toCol, finalValue)

    Q(accRow)

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: acc.newHeaders.concat([@_toCol])}
      else
        acc

  priority: () ->
    @_priority or 3000

###
  Transforms one object into another object accoring to the mapping configuration

  Options:
    mappingFile
    transformers
    columnMappers
###
class Mapping
  constructor: (options) ->
    @_mappingFile = options.mappingFile
    @_transformers = options.transformers
    @_columnMappers = options.columnMappers

  init: () ->
    util.loadFile @_mappingFile
    .then (contents) =>
      @_constructMapping(JSON.parse(contents))
    .then (mapping) =>
      @_columnMapping = mapping
      this

  _constructMapping: (mappingJson) ->
    columnPromises = _.map mappingJson.columnMapping, (elem) =>
      found = _.find @_columnMappers, (mapper) -> mapper.supports(elem)

      if found
        found.create(@_transformers, elem)
      else
        throw new Error("Unsupported column mapping type: #{elem.type}")

    Q.all columnPromises

  transformHeader: (groups, columnNames) ->
    _.reduce @_columnMapping, ((acc, mapping) -> mapping.transformHeader(acc, columnNames)), _.map(groups, (g) -> {group: g, newHeaders: []})

  transformRow: (groups, row) ->
    mappingsSorted = _.sortBy @_columnMapping, (mapping) -> mapping.priority()

    _.reduce mappingsSorted, ((accRowPromise, mapping) -> accRowPromise.then((accRow) -> mapping.map(row, accRow))), Q(_.map(groups, (g) -> {group: g, row: []}))

module.exports =
  ColumnMapping: ColumnMapping
  ColumnTransformer: ColumnTransformer
  CopyFromOriginalTransformer: CopyFromOriginalTransformer
  RemoveColumnsTransformer: RemoveColumnsTransformer
  ColumnGenerator: ColumnGenerator
  Mapping: Mapping
  defaultColumnMappers: [
    ColumnTransformer,
    CopyFromOriginalTransformer,
    RemoveColumnsTransformer
    ColumnGenerator
  ]