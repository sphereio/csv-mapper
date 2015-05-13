Q = require 'q'
fs = require 'q-io/fs'
{_} = require('underscore')
_s = require 'underscore.string'
yaml = require 'js-yaml'

util = require '../lib/util'
{mapping, transformer, condition} = require '../main'

Mapper = require('../main').Mapper

describe 'Mapping', ->
  createTestMapper = (testDir, mappingFile, mapperOptions) ->
    util.loadFile mappingFile
    .then (mappingText) ->
      new mapping.Mapping
        mappingConfig: yaml.safeLoad(mappingText)
        transformers: transformer.defaultTransformers
        conditions: condition.defaultConditions
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

  simpleMapping = (inObj, columnMapping) ->
    new mapping.Mapping
      transformers: transformer.defaultTransformers
      columnMappers: mapping.defaultColumnMappers
      mappingConfig:
        columnMapping: columnMapping
    .init()
    .then (mapping) ->
      mapping.transformRow ["default"], inObj

  it 'should map CSV file with standard mappings and produce 2 output CSV for "default" and "additional" groups based on JSON mapping', (done) ->
    withTestDir (testDir)->
      createTestMapper testDir, 'test-data/test-mapping.json',
        inCsv: 'test-data/test-small.csv'
        outCsv: "#{testDir}/test-small.actual.csv"
        group: 'default'
        additionalOutCsv: [{group: 'additional', file: "#{testDir}/test-small-additional.actual.csv"}]
      .then (count) ->
        expect(count).toBe 101

        Q.all [
          util.loadFile('test-data/test-small.expected.csv'),
          util.loadFile("#{testDir}/test-small.actual.csv"),
          util.loadFile('test-data/test-small-additional.expected.csv'),
          util.loadFile("#{testDir}/test-small-additional.actual.csv")
        ]
        .spread (expectedMainOut, actualMainOut, expectedAdditionalOut, actualAdditionalOut) ->
          expect(actualMainOut.toString()).toBe expectedMainOut.toString()
          expect(actualAdditionalOut.toString()).toBe expectedAdditionalOut.toString()
    .then ->
      done()
    .fail (error) ->
      done(error)

  it 'should map CSV file with standard mappings and produce 2 output CSV for "default" and "additional" groups based on YAML mapping', (done) ->
    withTestDir (testDir)->
      createTestMapper testDir, 'test-data/test-mapping.yaml',
        inCsv: 'test-data/test-small.csv'
        outCsv: "#{testDir}/test-small.actual-yaml.csv"
        group: 'default'
        additionalOutCsv: [{group: 'additional', file: "#{testDir}/test-small-additional.actual-yaml.csv"}]
      .then (count) ->
        expect(count).toBe 101

        Q.all [
          util.loadFile('test-data/test-small.expected.csv'),
          util.loadFile("#{testDir}/test-small.actual-yaml.csv"),
          util.loadFile('test-data/test-small-additional.expected.csv'),
          util.loadFile("#{testDir}/test-small-additional.actual-yaml.csv")
        ]
        .spread (expectedMainOut, actualMainOut, expectedAdditionalOut, actualAdditionalOut) ->
          expect(actualMainOut.toString()).toBe expectedMainOut.toString()
          expect(actualAdditionalOut.toString()).toBe expectedAdditionalOut.toString()
    .then ->
      done()
    .fail (error) ->
      done(error)

  it "should show nice message when multipart value transformer has part of the wring size", (done) ->
    simpleMapping {a: "Hello World!"}, [{
      type: "addColumn"
      toCol: "b"
      valueTransformers: [{
        type: "multipartString"
        parts: [{
          size: 10
          pad: "0"
          valueTransformers: [
            {type: "constant", value: "bar"}
          ]
        }, {
          size: 15
          fromCol: 'a'
          valueTransformers: [
            {type: "regexp", find: "^(.*)$", replace: "$1 - foo"}
          ]
        }]
      }]
    }]
    .then (result) ->
      done("No error message!")
    .fail (error) ->
      expectedMessage = "Error during generation of column 'b': Error: Generated column part size
        (18 - 'Hello World! - foo') is smaller than expected size (15) and no padding is defined for this column.
        Source column 'a' (part 1) with current value 'Hello World!'."
      expect(_s.startsWith(error.message, expectedMessage)).toBe true
      done()