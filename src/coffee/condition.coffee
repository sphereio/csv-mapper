Q = require 'q'
csv = require 'csv'

{_} = require 'underscore'
_s = require 'underscore.string'

util = require '../lib/util'

class Condition
  @create: (options) -> util.abstractMethod() # promise with transformer
  @supports: (options) -> util.abstractMethod() # boolean - whether options are supported

  check: (oldRow, newRow) -> util.abstractMethod() # promise of boolean (true - row matches the condition, false otherwise)

module.exports =
  Condition: Condition
  ConstantTransformer: ConstantTransformer
  defaultConditions: []
