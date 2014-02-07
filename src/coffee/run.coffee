argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret]')
  .alias('projectKey', 'k')
  .alias('clientId', 'i')
  .alias('clientSecret', 's')
  .describe('projectKey', 'Sphere.io project key.')
  .describe('clientId', 'Sphere.io HTTP API client id.')
  .describe('clientSecret', 'Sphere.io HTTP API client secret.')
  .demand(['projectKey', 'clientId', 'clientSecret'])
  .argv
Connector = require('../main').Connector

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret

connector = new Connector options
connector.run (success) ->
  process.exit 1 unless success