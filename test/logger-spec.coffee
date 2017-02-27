redis   = require 'fakeredis'
uuid    = require 'uuid'
Logger  = require '../src/logger'

describe 'Logger', ->
  beforeEach ->
    @clientId = uuid.v1()
    @rand = => 0.50

    @client = redis.createClient(@clientId, dropBufferSupport: true)
    client  = redis.createClient(@clientId, dropBufferSupport: true)

    @elasticsearch = bulk: sinon.stub().yields()

    timeout = 1
    interval = 1

    @sut = new Logger {client, @elasticsearch, interval, timeout, @rand}

  describe '-> run', ->
    describe 'When there is no job in the queue', ->
      it 'should call the callback before the test times out', (done) ->
        @sut.run done

    describe 'When there is one job in the queue', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'sample-rate:1.00', jobStr, done

      beforeEach (done) ->
        @sut.run done

      it 'should create an elasticsearch record', ->
        expect(@elasticsearch.bulk).to.have.been.calledWith
          body: [
            {index: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 1}
          ]

    describe 'When there are two jobs in the same queue', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'sample-rate:1.00', jobStr, done

      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 5}
        @client.lpush 'sample-rate:1.00', jobStr, done

      beforeEach (done) ->
        @sut.run done

      it 'should create both elasticsearch records', ->
        expect(@elasticsearch.bulk).to.have.been.calledWith
          body: [
            {index: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 1}
            {index: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 5}
          ]

    describe 'When there are two jobs in different queues', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'sample-rate:1.00', jobStr, done

      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 5}
        @client.lpush 'sample-rate:0.00', jobStr, done

      beforeEach (done) ->
        @sut.run done

      it 'should create one elasticsearch record', ->
        expect(@elasticsearch.bulk).to.have.been.calledWith
          body: [
            {index: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 1}
          ]

    describe 'When there is a job with an invalid sample rate', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'sample-rate:results-vary', jobStr, done

      beforeEach (done) ->
        @sut.run (@error) => done()

      it 'should yield an error', ->
        expect(@error).to.exist
        expect(=> throw @error).to.throw 'Invalid queueName: sample-rate:results-vary'
