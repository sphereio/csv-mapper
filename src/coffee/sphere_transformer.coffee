Q = require 'q'
csv = require 'csv'

_ = require('underscore')._
_s = require 'underscore.string'

util = require '../lib/util'
transformer = require('../lib/transformer')
Rest = require('sphere-node-connect').Rest

class SphereSequenceTransformer extends transformer.ValueTransformer
  @create: (transformers, options) ->
    Q(new SphereSequenceTransformer(transformers, options))

  @supports: (options) ->
    options.type is 'sphereSequence'

  constructor: (transformers, options) ->
    @_sphere = options.sphereService

    @_sequenceOptions =
      name: options.name
      initial: options.initial
      max: options.max
      min: options.min
      increment: options.increment
      rotate: options.rotate

  transform: (value, row) ->
    @_sphere.getAndIncrementCounter @_sequenceOptions

#class UniqueAttributeTransformer extends transformer.ValueTransformer
#  @create: (transformers, options) ->
#    Q(new ConstantTransformer(transformers, options))
#
#  @supports: (options) ->
#    options.type is 'constant'
#
#  constructor: (transformers, options) ->
#    @_value = options.value
#
#  transform: (value, row) ->
#    Q(@_value)

class ErrorStatusCode extends Error
  constructor: (@code, @body) ->
    @message = "Status code is #{@code}: #{JSON.stringify @body}"
    @name = 'ErrorStatusCode'
    Error.captureStackTrace this, this

class SphereService
  constructor: (options) ->
    @_sequenceNamespace = "sequence"

    @_client = new Rest options.connector
    @_repeater = new Repeater options.repeater
    @_incrementQueue = new TaskQueue
      taskFn: _.bind(@_doGetAndIncrementCounter, this)

  getAndIncrementCounter: (options) ->
    @_incrementQueue.addTask options

  _get: (path) ->
    d = Q.defer()

    @_client.GET path, (error, response, body) ->
      if error
        d.reject error
      else if response.statusCode is 200
        d.resolve body
      else
        d.reject new ErrorStatusCode(response.statusCode, body)

    d.promise

  _post: (path, json) ->
    d = Q.defer()

    @_client.POST path, json, (error, response, body) ->
      if error
        d.reject error
      else if response.statusCode is 200 or response.statusCode is 201
        d.resolve body
      else
        d.reject new ErrorStatusCode(response.statusCode, body)

    d.promise

  _incrementCounter: (json) ->
    val = json.value
    val.currentValue = @_nexCounterValue val

    @_post "/custom-objects", json
    .then (obj) ->
      val.currentValue

  _nexCounterValue: (config) ->
    newVal = config.currentValue + config.increment

    if (newVal > config.max or newVal < config.min) and not config.rotate
      throw new Error("Sequence '#{config.name}' is exhausted! #{JSON.stringify config}")
    else if newVal > config.max
      min
    else if newVal < config.min
      max
    else
      newVal

  _createSequence: (options) ->
    @_post "/custom-objects",
      container: @_sequenceNamespace
      key: options.name,
      value:
        name: options.name
        initial: options.initial
        max: options.max
        min: options.min
        increment: options.increment
        rotate: options.rotate
        currentValue: options.initial

  _doGetAndIncrementCounter: (options) ->
    @_repeater.execute
      recoverableError: (e) -> e instanceof ErrorStatusCode and e.code is 409
      task: () =>
        @_get "/custom-objects/#{@_sequenceNamespace}/#{options.name}"
        .then (json) =>
          @_incrementCounter(json)
        .fail (error) =>
          if error instanceof ErrorStatusCode and error.code is 404
            @_createSequence(options)
            .then (json) =>
              @_incrementCounter(json)
          else
            throw error

class Repeater
  constructor: (options) ->
    @_attempts = options.attempts
    @_timeout = options.timeout or 100

  execute: (options) ->
    d = Q.defer()

    @_repeat(@_attempts, options, d, null)

    d.promise

  _repeat: (attempts, options, defer, lastError) ->
    {task, recoverableError} = options

    if attempts is 0
      defer.reject new Error("Unsuccessful after #{@_attempts} attempts: #{lastError.message}")

    task()
    .then (res) ->
      defer.resolve res
    .fail (e) =>
      if recoverableError(e)
        Q.delay @_calculateDelay(attempts)
        .then (i) =>
          @_repeat(attempts - 1, options, defer, e)
      else
        defer.reject e
    .done()

  _calculateDelay: (attemptsLeft) ->
    tried = @_attempts - attemptsLeft - 1
    (@_timeout * tried) + _.random(50, @_timeout)

class TaskQueue
  constructor: (options) ->
    @_taskFn = options.taskFn
    @_queue = []
    @_active = false

  addTask: (taskOptions) ->
    d = Q.defer()

    @_queue.unshift {options: taskOptions, defer: d}
    @_maybeExecute()

    d.promise

  _maybeExecute: () ->
    if not @_active and @_queue.length > 0
      @_startTask @_queue.pop()
    else

  _startTask: (taskOptions) ->
    @_active = true

    p = @_taskFn taskOptions.options
    .then (res) ->
      taskOptions.defer.resolve res
    .fail (error) ->
      taskOptions.defer.reject error

    p.finally () =>
      @_active = false
      @_maybeExecute()

    p

module.exports =
  SphereSequenceTransformer: SphereSequenceTransformer
  SphereService: SphereService