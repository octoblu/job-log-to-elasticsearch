redis   = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
uuid    = require 'uuid'
Logger  = require '../src/logger'

describe 'Logger', ->
  beforeEach ->
    @clientId = uuid.v1()
    @rand = => 0

    @client = new RedisNS 'ns', redis.createClient(@clientId)
    client  = new RedisNS 'ns', redis.createClient(@clientId)

    @elasticsearch = bulk: sinon.stub().yields()

    timeout = 1
    interval = 1
    samplePercentage = 100
    @sut = new Logger {client, @elasticsearch, interval, timeout, samplePercentage, @rand}

  describe '-> run', ->
    describe 'When there is no job in the queue', ->
      it 'should call the callback before the test times out', (done) ->
        @sut.run done

    describe 'When there is one job in the queue', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'job-log', jobStr, done

      beforeEach (done) ->
        @sut.run done

      it 'should create an elasticsearch record', ->
        expect(@elasticsearch.bulk).to.have.been.calledWith
          body: [
            {create: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 1}
          ]

    describe 'When there are two jobs in the queue', ->
      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 1}
        @client.lpush 'job-log', jobStr, done

      beforeEach (done) ->
        jobStr = JSON.stringify index: 'meshblu_job', type: 'dispatcher', body: {elapsedTime: 5}
        @client.lpush 'job-log', jobStr, done

      beforeEach (done) ->
        @sut.run done

      it 'should create both elasticsearch records', ->
        expect(@elasticsearch.bulk).to.have.been.calledWith
          body: [
            {create: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 1}
            {create: {_index: 'meshblu_job', _type: 'dispatcher'}}
            {elapsedTime: 5}
          ]
