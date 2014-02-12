util = require '../lib/util'
_ = require('underscore')._

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
.describe('group', "The column group that should be used (by default '#{util.defaultGroup()}').")
.describe('additionalOutCsv', 'Addition output CSV files separated by comma `,` and optionally prefixed with `groupName:`.')
.demand(['mapping'])
#.demand(['projectKey', 'clientId', 'clientSecret', 'mapping'])

Mapper = require('../main').Mapper
transformer = require('../main').transformer
mapping = require('../main').mapping

argv = optimist.argv

if (argv.help)
  optimist.showHelp()
  process.exit 0

#mapperOptions =
#  config:
#    project_key: argv.projectKey
#    client_id: argv.clientId
#    client_secret: argv.clientSecret

parseAdditionalOutCsv = (config) ->
  if not config
    []
  else
    _.map config.split(/,/), (c) ->
      parts = c.split(/:/)

      if parts.length is 2
        {group: parts[0], file: parts[1]}
      else
        {group: util.defaultGroup(), file: parts[0]}


new mapping.Mapping
  mappingFile: argv.mapping
  transformers: transformer.defaultTransformers
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
    additionalOutCsv: parseAdditionalOutCsv(argv.additionalOutCsv)
  .run()
.then (count) ->
  console.info "\n\nProcessed #{count} lines"
  process.exit 0
.fail (error) ->
  console.error error.stack
  process.exit 1
