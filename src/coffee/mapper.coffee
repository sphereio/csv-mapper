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

  constructor: (options = {}) ->
    @options = options

  processCsv: (csvIn, csvOut, transformers = [], listeners = []) ->
    d = Q.defer()

    c = csv().from.stream(csvIn).to.stream(csvOut)

    csvWithTrans = _.foldl(transformers, ((c, trans) -> c.transform trans), c)
    csvWithListenars = _.foldl(listeners, ((c, listen) -> c.on 'record', listen), csvWithTrans)

    csvWithListenars.on('end', (count) -> d.resolve(count)).on('error', (error) -> d.reject(error))

    d.promise

  run: ->
    rowMutator = (row) ->
      row[0] = "Foo"
      row

    logger = (row) ->
#      console.info "Line: #{row}"

    Q.spread [util.fileStreamOrStdin(@options.inCsv), util.fileStreamOrStdout(@options.outCsv)], (csvIn, csvOut) =>
      @processCsv(csvIn, csvOut, [rowMutator], [logger])
      .finally () =>
        if util.nonEmpty @options.outCsv then util.closeStream(csvOut) else Q()

module.exports = Mapper
