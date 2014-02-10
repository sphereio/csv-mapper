optimist = require('optimist')
.usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret]')
.alias('projectKey', 'k')
.alias('clientId', 'i')
.alias('clientSecret', 's')
.alias('help', 'h')
.describe('help', 'Shows usage info and exits.')
.describe('projectKey', 'Sphere.io project key.')
.describe('clientId', 'Sphere.io HTTP API client id.')
.describe('clientSecret', 'Sphere.io HTTP API client secret.')
.describe('inCsv', 'The input product CSV file (optional, STDIN would be used if not specified).')
.describe('outCsv', 'The output product CSV file (optional, STDOUT would be used if not specified).')
#.demand(['projectKey', 'clientId', 'clientSecret'])

Mapper = require('../main').Mapper

argv = optimist.argv

if (argv.help)
  optimist.showHelp()
  process.exit 0

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret

new Mapper
  inCsv: argv.inCsv
  outCsv: argv.outCsv
.run()
.then (count) ->
  process.exit 0
.fail (error) ->
  console.error error
  process.exit 1
