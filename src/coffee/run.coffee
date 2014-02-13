_ = require('underscore')._

util = require '../lib/util'
package_json = require '../package.json'

optimist = require('optimist')
.usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret]')
.alias('projectKey', 'k')
.alias('clientId', 'i')
.alias('clientSecret', 's')
.alias('help', 'h')
.alias('mapping', 'm')
.describe('help', 'Shows usage info and exits.')
.describe('projectKey', 'Sphere.io project key.')
.describe('clientId', 'Sphere.io HTTP API client id.')
.describe('clientSecret', 'Sphere.io HTTP API client secret.')
.describe('inCsv', 'The input product CSV file (optional, STDIN would be used if not specified).')
.describe('outCsv', 'The output product CSV file (optional, STDOUT would be used if not specified).')
.describe('csvDelimiter', 'CSV delimiter (by default ,).')
.describe('csvQuote', 'CSV quote (by default ").')
.describe('mapping', 'Mapping JSON file or URL.')
.describe('group', "The column group that should be used.")
.describe('additionalOutCsv', 'Addition output CSV files separated by comma `,` and optionally prefixed with `groupName:`.')
.describe('timeout', 'Set timeout for requests')
.default('timeout', 300000)
.default('group', "default")
.demand(['projectKey', 'clientId', 'clientSecret', 'mapping'])

Mapper = require('../main').Mapper
transformer = require('../main').transformer
sphere_transformer = require('../main').sphere_transformer
mapping = require('../main').mapping

argv = optimist.argv

if (argv.help)
  optimist.showHelp()
  process.exit 0

sphereService = new sphere_transformer.SphereService
  connector:
    config:
      project_key: argv.projectKey
      client_id: argv.clientId
      client_secret: argv.clientSecret
    timeout: argv.timeout
    user_agent: "#{package_json.name} - #{package_json.version}"
  repeater:
    attempts: 5
    timeout: 100

sphereSequence = new transformer.AdditionalOptionsWrapper sphere_transformer.SphereSequenceTransformer,
  sphereService: sphereService

new mapping.Mapping
  mappingFile: argv.mapping
  transformers: transformer.defaultTransformers.concat [sphereSequence]
  columnMappers: mapping.defaultColumnMappers
.init()
.then (mapping) ->
  new Mapper
    inCsv: argv.inCsv
    outCsv: argv.outCsv
    csvDelimiter: argv.csvDelimiter
    csvQuote: argv.csvQuote
    mapping: mapping
    group: argv.group
    additionalOutCsv: util.parseAdditionalOutCsv(argv.additionalOutCsv)
  .run()
.then (count) ->
  console.info "\n\nProcessed #{count} lines"
  process.exit 0
.fail (error) ->
  console.error error.stack
  process.exit 1
.done()
