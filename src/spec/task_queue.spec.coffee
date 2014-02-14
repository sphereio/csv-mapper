Q = require 'q'
_ = require('underscore')._

{TaskQueue} = require('../lib/task_queue')

describe 'TaskQueue', ->
  it 'should execute tasks one after another', (done) ->
    processed = [false, false, false]

    queue = new TaskQueue
      taskFn: (opts) ->
        processed[opts.idx] = true
        _.each processed, (p, idx) ->
          expect(p).toBe (idx <= opts.idx)
        Q(true)

    Q.all [queue.addTask({idx: 0}), queue.addTask({idx: 1}), queue.addTask({idx: 2})]
    .then ->
      expect(processed).toEqual [true, true, true]
      done()
    .fail (error) ->
      done(error)

  it 'should should bouble up an error', (done) ->
    queue = new TaskQueue
      taskFn: (opts) ->
        Q.reject("foo")

    queue.addTask({})
    .then ->
      done("No error")
    .fail (error) ->
      expect(error).toEqual "foo"
      done()
    .done()
