Q = require 'q'
csv = require 'csv'

{_} = require 'underscore'
_s = require 'underscore.string'

util = require '../lib/util'

class Condition
  @create: (options) -> util.abstractMethod() # promise with transformer
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  check: (oldRow, newRow) -> util.abstractMethod() # promise of boolean (true - row matches the condition, false otherwise)

  _matches: (props, oldRow, newRow, matchFn) ->
    _.every _.keys(props), (key) ->
      expected = props[key]
      propName = key.replace /\.(new|old)$/, ''
      actualLookups = []

      if not _s.endsWith(key, ".old")
        actualLookups = actualLookups.concat(_.map(_.keys(newRow), ((nrk) -> newRow[nrk].row)))

      if not _s.endsWith(key, ".new")
        actualLookups.push oldRow

      _.some actualLookups, (lookup) ->
        lookup[propName]? && matchFn(lookup[propName], expected)

class InCondition extends Condition
  @create: (transformers, options) ->
    Q(new InCondition(transformers, options))

  @supports: (options) ->
    options.in?

  constructor: (conditions, options) ->
    @_body = options.in

  check: (oldRow, newRow) ->
    res = @_matches @_body, oldRow, newRow, (actual, expectedArray) ->
      _.contains expectedArray, actual
    Q(res)

class InCondition extends Condition
  @create: (transformers, options) ->
    Q(new InCondition(transformers, options))

  @supports: (options) ->
    options.in?

  constructor: (conditions, options) ->
    @_body = options.in

  check: (oldRow, newRow) ->
    res = @_matches @_body, oldRow, newRow, (actual, expectedArray) ->
      _.contains expectedArray, actual
    Q(res)

module.exports =
  Condition: Condition
  InCondition: InCondition
  defaultConditions: [
    InCondition
  ]
