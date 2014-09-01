Q = require 'q'
fs = require 'q-io/fs'
http = require 'q-io/http'

stdFs = require 'fs'
{_} = require 'underscore'
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
        [stdFs.createReadStream(filePath), false]
      else
        [process.stdin, true]

  fileStreamOrStdout: (filePath) ->
    if (@nonEmpty filePath)
      Q([stdFs.createWriteStream(filePath), false])
    else
      Q([process.stdout, true])

  closeStream: (stream) ->
    d = Q.defer()

    stream.on 'finish', -> d.resolve()
    stream.on 'error', (e) -> d.reject(e)

    stream.end()

    d.promise

  nonEmpty: (str) ->
    str and _s.trim(str).length > 0

  abstractMethod: ->
    throw new Error('Method not implemented!')

  notImplementedYet: ->
    throw new Error('Method not implemented!')

  defaultGroup: -> "default"

  virtualGroup: -> "virtual"

  withSafeValue: (value, fn) ->
    if @nonEmpty(value) then fn(value) else Q(value)

  transformValue: (valueTransformers, value, row) ->
    _.reduce valueTransformers, ((acc, transformer) -> acc.then((v) -> transformer.transform(v, row))), Q(value)

  transformFirstValue: (valueTransformers, value, row) ->
    if valueTransformers.length is 0
      value
    else
      _.head(valueTransformers).transform value, row
      .then (newVal) =>
        if @nonEmpty(newVal)
          newVal
        else
          @transformFirstValue _.tail(valueTransformers), value, row

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
      _.map config.split(/,/), (c) =>
        parts = c.split(/:/)

        if parts.length is 2
          {group: parts[0], file: parts[1]}
        else
          {group: @defaultGroup(), file: parts[0]}
