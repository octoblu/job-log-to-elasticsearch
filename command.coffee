### !pragma coverage-skip-block ###

async         = require 'async'
commander     = require 'commander'
elasticsearch = require 'elasticsearch'
redis         = require 'ioredis'
packageJSON   = require './package.json'
Logger        = require './src/logger'

class Command
  constructor: ->

  parseOptions: =>
    commander
      .version packageJSON.version
      .usage 'Run the job-log-to-elasticsearch worker'
      .option '-e, --elasticsearch-uri <es.octoblu.com:80>', 'Elasticsearch URI (env J2E_ELASTICSEARCH_URI)'
      .option '-i, --interval <interval>', 'How often to log to elasticsearch (env J2E_INTERVAL)'
      .option '-r, --redis-uri <redis://localhost:6379>', 'Redis URI. (env J2E_REDIS_URI)'
      .option '-t, --timeout <15>', 'Redis BRPOP timeout. (env J2E_TIMEOUT)'
      .parse process.argv

    @elasticsearchUri = commander.elasticsearchUri ? process.env.J2E_ELASTICSEARCH_URI || 'es.octoblu.com:80'
    @interval = parseInt(commander.interval ? process.env.J2E_INTERVAL || '1')
    @timeout = parseInt(commander.timeout ? process.env.J2E_TIMEOUT || '15')
    @redisUri = commander.redisUri ? process.env.J2E_REDIS_URI || 'redis://localhost:6379'
    @rand = Math.random

  run: =>
    @parseOptions()
    @elasticsearch = elasticsearch.Client host: @elasticsearchUri

    @client = redis.createClient @redisUri, dropBufferSupport: true

    @client.on 'ready', =>
      async.forever @singleRun, (error) =>
        console.error error.stack
        process.exit 1

    @client.on 'error', (error) =>
      console.error error.stack
      process.exit 1

    process.on 'SIGTERM', =>
      @shouldExit = true

  singleRun: (callback) =>
    return process.exit 0 if @shouldExit

    logger = new Logger {@client, @elasticsearch, @interval, @timeout, @rand}
    logger.run (error) =>
      return callback error if error?
      process.nextTick callback

command = new Command
command.run()
