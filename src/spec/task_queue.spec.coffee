Q = require 'q'
{_} = require 'underscore'

{BatchTaskQueue} = require('../lib/task_queue')

describe 'BatchTaskQueue', ->
  it 'should execute tasks one after another', (done) ->
    processed = [false, false, false]

    queue = new BatchTaskQueue
      taskFn: (tasks) ->
        _.each tasks, (t) ->
          processed[t.options.idx] = true
          _.each processed, (p, idx) ->
            expect(p).toBe (idx <= t.options.idx)
          t.defer.resolve true
        Q(true)

    Q.all [queue.addTask({idx: 0}), queue.addTask({idx: 1}), queue.addTask({idx: 2})]
    .then ->
      expect(processed).toEqual [true, true, true]
      done()
    .fail (error) ->
      done(error)

  it 'should should bouble up an error', (done) ->
    queue = new BatchTaskQueue
      taskFn: (tasks) ->
        Q.reject("foo")

    queue.addTask({})
    .then ->
      done("No error")
    .fail (error) ->
      expect(error).toEqual "foo"
      done()
    .done()
