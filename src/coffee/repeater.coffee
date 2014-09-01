Q = require 'q'
{_} = require 'underscore'

class Repeater
  constructor: (options) ->
    @_attempts = options.attempts
    @_timeout = options.timeout or 100
    @_timeoutType = options.timeoutType

  execute: (options) ->
    d = Q.defer()

    @_repeat(@_attempts, options, d, null)

    d.promise

  _repeat: (attempts, options, defer, lastError) ->
    {task, recoverableError} = options

    if attempts is 0
      defer.reject new Error("Unsuccessful after #{@_attempts} attempts: #{lastError.message}")
    else
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
    if @_timeoutType is 'constant'
      @_timeout
    else
      tried = @_attempts - attemptsLeft - 1
      (@_timeout * tried) + _.random(50, @_timeout)

exports.Repeater = Repeater
