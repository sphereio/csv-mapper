Config = require '../config'
Connector = require('../main').Connector
Q = require('q')

# Increase timeout
jasmine.getEnv().defaultTimeoutInterval = 10000

describe '#run', ->
  beforeEach (done) ->
    @connector = new Connector Config
    done()

  it 'Nothing to do', (done) ->
    @connector.run (success) ->
      expect(success).toBe true
      done()
