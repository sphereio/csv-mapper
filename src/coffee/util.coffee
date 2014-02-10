Q = require 'q'
fs = require "q-io/fs"
http = require "q-io/http"

stdFs = require "fs"
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
      fs.read fileOrUrl, "r"

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

    stream.on "finish", () -> d.resolve()
    stream.on "error", (e)-> d.reject(e)

    d.promise

  nonEmpty: (str) ->
    _s.trim(str).length > 0