Q = require 'q'
fs = require "q-io/fs"
http = require "q-io/http"

_ = require('underscore')._
_s = require 'underscore.string'

###
  Module has some utility functions
###
module.exports =
  # load file of URL and returns a string promice
  loadFile: (fileOrUrl) ->
    if _s.startsWith(fileOrUrl, 'http')
      http.read fileOrUrl
    else
      fs.read fileOrUrl, "r"

