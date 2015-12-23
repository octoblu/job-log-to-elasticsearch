async = require 'async'

class Logger
  constructor: ({@client, @elasticsearch, @interval, @timeout}) ->

  run: (callback) =>
    endTime = Date.now() + (@interval * 1000)
    endTimeExceeded = -> endTime < Date.now()

    @bulkRecords = []

    async.until endTimeExceeded, @popLog, (error) =>
      return callback error if error?

      @elasticsearch.bulk body: @bulkRecords, callback

  popLog: (callback) =>
    @client.brpop 'job-log', @timeout, (error, result) =>
      return callback error if error?
      return callback() unless result?

      [channel,jobStr] = result
      job = JSON.parse jobStr

      @bulkRecords.push create: {_index: job.index, _type: job.type}
      @bulkRecords.push job.body
      callback()

module.exports = Logger
