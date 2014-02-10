fs = require 'fs'
Q = require 'q'
_ = require('underscore')._
_s = require 'underscore.string'
util = require 'util'

###
  Does stuff!

  Options:
    inStream - the source of the CSV data
    b - bar
    c - baz
###
class CsvReader

  defaultOptions = {}

  constructor: (options = {}) ->
    @options = _.extend({}, defaultOptions, options)


module.exports = CsvReader
