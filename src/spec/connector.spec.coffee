Config = require '../config'
Connector = require('../main').Connector

describe 'Connector initialization', ->

  it 'should initialize with default values', ->
    connector = new Connector
    expect(connector).toBeDefined()
    expect(connector._options).toBeDefined()
    expect(connector._options).toEqual {}

  it 'should initialize with values', ->
    options =
      config:
        key: 'value'
    connector = new Connector options
    expect(connector).toBeDefined()
    expect(connector._options).toBeDefined()
    expect(connector._options).toEqual options

describe 'Connector', ->
  beforeEach ->
    @connector = new Connector

  afterEach ->
    @connector = null

  it 'should return true', ->
    connector = new Connector
    connector.run (success) ->
      expect(success).toBe true
