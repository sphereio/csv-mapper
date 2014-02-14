Q = require 'q'
csv = require 'csv'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

class ColumnMapping
  @create: (options) -> util.abstractMethod() # promise with mapplig
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  constructor: (transformers, options) ->
    @_transformers = transformers

    @_priority = options.priority
    @_groups = options.groups or [util.defaultGroup()]

  map: (origRow, accRow) -> util.abstractMethod() # mapped row promice
  transformHeader: (headerAccumulator, originalHeader) -> util.abstractMethod() # array of string with the new updated header
  _defaultPriority: () -> util.abstractMethod() # int

  priority: () ->
    @_priority or @_defaultPriority()

  supportsGroup: (group) ->
    _.contains @_groups, group

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
    super(transformers, options)

    @_includeCols = options.includeCols
    @_excludeCols = options.excludeCols

  map: (origRow, accRow) ->
    _.each accRow, (acc) =>
      if @supportsGroup(acc.group)
        _.each _.keys(origRow), (name) =>
          if @_include(name)
            acc.row[name] = origRow[name]

    Q(accRow)

  _include: (name) ->
    (not @_includeCols or _.contains(@_includeCols, name)) and (not @_excludeCols or not _.contains(@_excludeCols, name))

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: acc.newHeaders.concat _.filter(originalHeader, ((name) => @_include(name)))}
      else
        acc

  _defaultPriority: () -> 1000

class RemoveColumnsTransformer extends ColumnMapping
  @create: (transformers, options) ->
    Q(new RemoveColumnsTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'removeColumns'

  constructor: (transformers, options) ->
    super(transformers, options)

    @_cols = options.cols or []

  map: (origRow, accRow) ->
    _.each accRow, (acc) =>
      if @supportsGroup(acc.group)
        _.each _.keys(acc.row), (name) =>
          if _.contains(@_cols, name)
            delete acc.row[name]

    Q(accRow)

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: _.filter(acc.newHeaders, ((name) => not _.contains(@_cols, name)))}
      else
        acc

  _defaultPriority: () -> 1500

class ColumnTransformer extends ColumnMapping
  @create: (transformers, options) ->
    (new ColumnTransformer(transformers, options))._init()

  @supports: (options) ->
    options.type is 'transformColumn' or options.type is 'addColumn'

  constructor: (transformers, options) ->
    super(transformers, options)

    @_fromCol = options.fromCol
    @_toCol = options.toCol
    @_type = options.type
    @_valueTransformersConfig = options.valueTransformers

  _init: () ->
    util.initValueTransformers @_transformers, @_valueTransformersConfig
    .then (vt) =>
      @_valueTransformers = vt
      this

  map: (origRow, accRow) ->
    value = @_getPropertyForGroup origRow, accRow, @_fromCol

    if @_containsSupportedGroup(accRow)
      mergedRow = _.reduce _.map(accRow, (acc) -> acc.row), ((acc, obj) ->_.extend(acc, obj)), origRow

      util.transformValue(@_valueTransformers, value, mergedRow)
      .then (finalValue) =>
        @_updatePropertyInGroups(accRow, @_toCol, finalValue)
        accRow
      .fail (error) =>
        fromMessage = if @_fromCol then "mapping from column '#{@_fromCol}' to" else "generation of"
        valueMessage = if value then " with current value '#{value}'" else ""
        throw new Error("Error during #{fromMessage} column '#{@_toCol}'#{valueMessage}: #{error.message}")
    else
      Q(accRow)

  transformHeader: (headerAccumulator, originalHeader) ->
    _.map headerAccumulator, (acc) =>
      if @supportsGroup(acc.group)
        {group: acc.group, newHeaders: acc.newHeaders.concat([@_toCol])}
      else
        acc

  _defaultPriority: () ->
    if @_type is 'addColumn' then 3000 else 2000

###
  Transforms one object into another object accoring to the mapping configuration

  Options:
    mappingConfig
    transformers
    columnMappers
###
class Mapping
  constructor: (options) ->
    @_mappingConfig = options.mappingConfig
    @_transformers = options.transformers
    @_columnMappers = options.columnMappers

  init: () ->
    @_constructMapping(@_mappingConfig)
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
  Mapping: Mapping
  defaultColumnMappers: [
    ColumnTransformer,
    CopyFromOriginalTransformer,
    RemoveColumnsTransformer
  ]