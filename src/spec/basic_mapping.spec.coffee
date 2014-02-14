Q = require 'q'
fs = require 'q-io/fs'
_ = require('underscore')._

util = require '../lib/util'
mapping = require('../main').mapping
transformer = require('../main').transformer

Mapper = require('../main').Mapper

describe 'Mapping', ->
  createTestMapping = (testDir, mappingFile, mapperOptions) ->
    util.loadFile mappingFile
    .then (mappingText) ->
      new mapping.Mapping
        mappingConfig: JSON.parse(mappingText)
        transformers: transformer.defaultTransformers
        columnMappers: mapping.defaultColumnMappers
      .init()
    .then (mapping) ->
      new Mapper _.extend({}, {mapping: mapping}, mapperOptions)
      .run()

  withTestDir = (cb)->
    testDir = "test-data-#{_.random(1000, 100000)}"

    fs.makeDirectory testDir
    .then ->
      cb(testDir)
    .finally ->
      fs.removeTree testDir

  it 'should map CSV file with standard mappings and produce 2 output CSV for "default" and "additional" groups', (done) ->
    withTestDir (testDir)->
      createTestMapping testDir, 'test-data/test-mapping.json',
        inCsv: 'test-data/test-small.csv'
        outCsv: "#{testDir}/test-small.actual.csv"
        group: 'default'
        additionalOutCsv: [{group: 'additional', file: "#{testDir}/test-small-additional.actual.csv"}]
      .then (count) ->
        expect(count).toBe 101

        mainPromise = util.loadFile('test-data/test-small.expected.csv')
        .then (expectedMainOut) ->
          util.loadFile("#{testDir}/test-small.actual.csv")
          .then (actualMainOut) ->
            expect(actualMainOut.toString()).toBe expectedMainOut.toString()

        additionalPromise = util.loadFile('test-data/test-small-additional.expected.csv')
        .then (expectedAdditionalOut) ->
          util.loadFile("#{testDir}/test-small-additional.actual.csv")
          .then (actualAdditionalOut) ->
            expect(actualAdditionalOut.toString()).toBe expectedAdditionalOut.toString()

        Q.all [mainPromise, additionalPromise]
    .then ->
      done()
    .fail (error) ->
      done(error)
