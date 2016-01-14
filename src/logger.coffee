_     = require 'lodash'
async = require 'async'
debug = require('debug')('job-log-to-elasticsearch:logger')

class Logger
  constructor: ({@client, @elasticsearch, @interval, @timeout, @samplePercentage, @rand}) ->

  run: (callback) =>
    debug 'run'
    endTime = Date.now() + (@interval * 1000)
    endTimeExceeded = -> endTime < Date.now()

    @bulkRecords = []

    async.until endTimeExceeded, @popLog, (error) =>
      return callback error if error?
      debug 'endTimeExceeded', numberOfBulkRecords: _.size(@bulkRecords)
      return callback() if _.isEmpty @bulkRecords

      @elasticsearch.bulk body: @bulkRecords, callback

  popLog: (callback) =>
    @client.brpop 'job-log', @timeout, (error, result) =>
      return callback error if error?
      return callback() unless result?
      return callback() unless @rollTheDice()

      [channel,jobStr] = result
      job = JSON.parse jobStr

      @bulkRecords.push create: {_index: job.index, _type: job.type}
      @bulkRecords.push job.body
      callback()

  rollTheDice: =>
    @rand() <= (@samplePercentage / 100)

module.exports = Logger
