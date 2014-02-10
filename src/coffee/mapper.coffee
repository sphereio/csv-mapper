Q = require 'q'
csv = require 'csv'
fs = require 'fs'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'

###
  Does stuff!

  Options:
    in - input CSV file
    b - bar
    c - baz
###
class Mapper

  defaultOptions = {}

  constructor: (options = {}) ->
    @options = _.extend({}, defaultOptions, options)

  run: ->
#    util.loadFile("http://stackoverflow.com/questions/646628/javascript-startswith")

    csv()
      .from.stream(fs.createReadStream("/Users/oilyenko/dev/prj-ct/sphere-product-mapper/test-data/product-data.csv"))
      .to.path("/Users/oilyenko/dev/prj-ct/sphere-product-mapper/test-data/product-data-out.csv")
      .transform (row) ->
        row.unshift row.pop()
        row
      .on 'record', (row, index) ->
        console.log('#'+index+' '+ JSON.stringify(row))
      .on 'end', (count) ->
        console.log('Number of lines: '+count)
      .on 'error', (error) ->
        console.log(error.message)

    util.loadFile("/Users/oilyenko/dev/prj-ct/sphere-product-mapper/main.js")
      .then (contents) ->
        console.info "#{contents}"
      .fail (error) ->
        console.err error


module.exports = Mapper
