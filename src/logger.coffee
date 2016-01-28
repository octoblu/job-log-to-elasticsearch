_     = require 'lodash'
async = require 'async'
debug = require('debug')('job-log-to-elasticsearch:logger')

class Logger
  constructor: ({@client, @elasticsearch, @interval, @timeout, @rand}) ->

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
    @client.keys 'sample-rate:*', (error, keys) =>
      return callback error if error?
      return callback() if _.isEmpty keys

      @client.brpop keys..., @timeout, (error, result) =>
        return callback error if error?
        return callback() unless result?

        [channel,jobStr] = result

        try
          sampleRate = @parseSampleRate channel
        catch error
          return callback error

        return callback() unless @rollTheDice(sampleRate)
        job = JSON.parse jobStr

        @bulkRecords.push create: {_index: job.index, _type: job.type}
        @bulkRecords.push job.body
        callback()

  parseSampleRate: (channel) =>
    sampleRate = parseFloat(_.last(_.split(channel, ':')))
    if _.isNaN sampleRate
      throw new Error "Invalid queueName: #{channel}"
    return sampleRate

  rollTheDice: (sampleRate) =>
    return @rand() <= (sampleRate * 100)

module.exports = Logger
