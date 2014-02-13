Q = require 'q'

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

exports.TaskQueue = TaskQueue