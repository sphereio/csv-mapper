Q = require 'q'
fs = require 'q-io/fs'
http = require 'q-io/http'

stdFs = require 'fs'
_ = require('underscore')._
_s = require 'underscore.string'

###
  Module has some utility functions
###
module.exports =
  # load file from local FS or URL and returns a string promise
  loadFile: (fileOrUrl) ->
    if _s.startsWith(fileOrUrl, 'http')
      http.read fileOrUrl
    else
      fs.read fileOrUrl, 'r'

  fileStreamOrStdin: (filePath) ->
    fs.exists(filePath).then (exists) ->
      if exists
        stdFs.createReadStream filePath
      else
        process.stdin

  fileStreamOrStdout: (filePath) ->
    if (@nonEmpty filePath)
      Q(stdFs.createWriteStream filePath)
    else
      Q(process.stdout)

  closeStream: (stream) ->
    d = Q.defer()

    stream.end()

    stream.on 'finish', -> d.resolve()
    stream.on 'error', (e)-> d.reject(e)

    d.promise

  nonEmpty: (str) ->
    str and _s.trim(str).length > 0

  abstractMethod: ->
    throw new Error('Method not implemented!')

  notImplementedYet: ->
    throw new Error('Method not implemented!')

  defaultGroup: -> "default"

  transformValue: (valueTransformers, value, row) ->
    safeValue = if @nonEmpty(value) then value else ''
    _.reduce valueTransformers, ((acc, transformer) -> acc.then((v) -> transformer.transform(v, row))), Q(safeValue)

  initValueTransformers: (transformers, transformerConfig) ->
    if transformerConfig
      promises = _.map transformerConfig, (config) ->
        found  = _.find transformers, (t) -> t.supports(config)

        if found
          found.create transformers, config
        else
          throw new Error("unsupported value transformer type: #{config.type}")

      Q.all promises
    else
      Q([])

  parseAdditionalOutCsv: (config) ->
    if not config
      []
    else
      _.map config.split(/,/), (c) ->
        parts = c.split(/:/)

        if parts.length is 2
          {group: parts[0], file: parts[1]}
        else
          {group: @defaultGroup(), file: parts[0]}
