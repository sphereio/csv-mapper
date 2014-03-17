Q = require 'q'
_ = require('underscore')._

class BatchTaskQueue
  constructor: (options) ->
    @_taskFn = options.taskFn
    @_queue = []
    @_active = false

  addTask: (taskOptions) ->
    d = Q.defer()

    @_queue.push {options: taskOptions, defer: d}
    @_maybeExecute()

    d.promise

  _maybeExecute: ->
    if not @_active and @_queue.length > 0
      @_startTasks @_queue
      @_queue = []

  _startTasks: (tasks) ->
    @_active = true

    @_taskFn tasks
    .fail (error) ->
      _.each tasks, (t) -> t.defer.reject error
    .finally =>
      @_active = false
      @_maybeExecute()

exports.BatchTaskQueue = BatchTaskQueue
