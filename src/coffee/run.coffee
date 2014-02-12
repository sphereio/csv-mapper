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
.describe('mapping', 'Mapping JSON file or URL.')
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

new mapping.Mapping
  mappingFile: argv.mapping
  transformers: transformer.defaultTransformers
  columnMappers: mapping.defaultColumnMappers
.init()
.then (mapping) ->
  new Mapper
    inCsv: argv.inCsv
    outCsv: argv.outCsv
    mapping: mapping
  .run()
.then (count) ->
  process.exit 0
.fail (error) ->
  console.error error.stack
  process.exit 1
