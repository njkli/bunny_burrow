require 'spec_helper'

describe BunnyBurrow::Base do
  describe 'default initialization' do
    subject { described_class.new }

    it 'yields if a block is given' do
      expect { |b| described_class.new &b }.to yield_control
    end

    it 'does not yield if a block is not given' do
      allow_any_instance_of(BunnyBurrow::Base).to receive(:block_given?).and_return(false)
      expect { |b| described_class.new &b }.to_not yield_control
    end

    it 'defaults timeout to 60' do
      expect(subject.timeout).to eq(60)
    end

    it 'defaults log_request to false' do
      expect(subject.log_request?).to be_falsey
    end

    it 'defaults log_response to false' do
      expect(subject.log_response?).to be_falsey
    end

    it 'defaults verify_peer to true' do
      expect(subject.verify_peer?).to be true
    end

    it 'defaults own_connection to true' do
      expect(subject.instance_variable_get('@own_connection')).to be(true)
      expect(subject.instance_variable_get('@connection')).to be_nil
    end
  end # describe 'default initialization'

  describe 'custom initialization' do
    let(:rabbitmq_url)      { 'rabbitmq_url' }
    let(:rabbitmq_exchange) { 'rabbitmq_exchange' }
    let(:rabbitmq_connection) { double 'connection' }
    let(:logger)            { 'logger' }
    let(:log_prefix)        { 'log_prefix' }
    let(:timeout)           { rand(60) + 1 }

    subject do
      described_class.new do |dc|
        dc.rabbitmq_url = rabbitmq_url
        dc.rabbitmq_exchange = rabbitmq_exchange
        dc.rabbitmq_connection = rabbitmq_connection
        dc.logger = logger
        dc.log_prefix = log_prefix
        dc.timeout = timeout
        dc.log_request = true
        dc.log_response = true
        dc.verify_peer = false
      end
    end

    it 'allows rabbitmq_url to be set' do
      expect(subject.rabbitmq_url).to eq(rabbitmq_url)
    end

    it 'allows rabbitmq_exchange to be set' do
      expect(subject.rabbitmq_exchange).to eq(rabbitmq_exchange)
    end

    it 'allows rabbitmq_connection to be set' do
      expect(subject.rabbitmq_connection).to eq(rabbitmq_connection)
      expect(subject.instance_variable_get('@connection')).to eq(rabbitmq_connection)
      expect(subject.instance_variable_get('@own_connection')).to be(false)
    end

    it 'allows logger to be set' do
      expect(subject.logger).to eq(logger)
    end

    it 'allows log_prefix to be set' do
      expect(subject.log_prefix).to eq(log_prefix)
    end

    it 'allows timeout to be set' do
      expect(subject.timeout).to eq(timeout)
    end

    it 'allows log_request to be set' do
      expect(subject.log_request?).to be_truthy
    end

    it 'allows log_response to be set' do
      expect(subject.log_response?).to be_truthy
    end

    it 'allows verify_peer to be set' do
      expect(subject.verify_peer?).to be_falsey
    end
  end # describe 'custom initialization'

  describe 'instance' do
    let(:channel)            { double 'channel' }
    let(:condition)          { double 'ConditionVariable' }
    let(:connection)         { double 'Bunny' }
    let(:default_exchange)   { double 'default exchange' }
    let(:default_log_level)  { :info }
    let(:default_log_prefix) { 'BunnyBurrow' }
    let(:lock)               { double 'Mutex' }
    let(:logger)             { double 'Logger' }
    let(:message)            { 'some log message' }
    let(:topic_exchange)     { double 'topic exchange' }

    subject { described_class.new }

    before(:each) do
      subject.instance_variable_set('@connection', connection)
      subject.instance_variable_set('@channel', channel)
      allow(subject).to receive(:logger).and_return(logger)
    end

    it 'creates a connection when one does not exist' do
      allow(connection).to receive(:start)
      subject.instance_variable_set('@connection', nil)
      expect(Bunny).to receive(:new).and_return(connection)
      subject.send :connection
    end

    it 'sets verify_peer on the connection' do
      allow(connection).to receive(:start)
      subject.instance_variable_set('@connection', nil)
      expect(Bunny).to receive(:new).and_return(connection).with(anything, verify_peer: true)
      subject.send :connection
    end

    it 'uses an existing connection' do
      expect(Bunny).not_to receive(:new)
      expect(connection).not_to receive(:start)
      subject.send :connection
    end

    it 'creates a channel when one does not exist' do
      subject.instance_variable_set('@channel', nil)
      expect(connection).to receive(:create_channel)
      subject.send :channel
    end

    it 'uses an existing channel' do
      expect(connection).not_to receive(:create_channel)
      subject.send :channel
    end

    it 'creates a default exchange variable when one does not exist' do
      expect(channel).to receive(:default_exchange)
      subject.send :default_exchange
    end

    it 'uses an existing default exchange variable' do
      subject.instance_variable_set('@default_exchange', default_exchange)
      expect(channel).not_to receive(:default_exchange)
      subject.send :default_exchange
    end

    it 'creates a topic exchange when one does not exist' do
      expect(channel).to receive(:topic)
      subject.send :topic_exchange
    end

    it 'uses an existing topic exchange' do
      subject.instance_variable_set('@topic_exchange', topic_exchange)
      expect(channel).not_to receive(:topic)
      subject.send :topic_exchange
    end

    it 'creates a lock when one does not exist' do
      subject.instance_variable_set('@lock', nil)
      expect(Mutex).to receive(:new)
      subject.send :lock
    end

    it 'uses an existing lock' do
      subject.instance_variable_set('@lock', lock)
      expect(Mutex).not_to receive(:new)
      subject.send :lock
    end

    it 'creates a condition when one does not exist' do
      subject.instance_variable_set('@condition', nil)
      expect(ConditionVariable).to receive(:new)
      subject.send :condition
    end

    it 'uses an existing condition variable' do
      subject.instance_variable_set('@condition', condition)
      expect(ConditionVariable).not_to receive(:new)
      subject.send :condition
    end

    it 'does not log if no logger' do
      allow(subject).to receive(:logger).and_return(nil)
      expect { subject.send :log, message }.not_to raise_error
    end

    it 'logs when there is a logger' do
      expect(logger).to receive(default_log_level)
      subject.send :log, message
    end

    it 'defaults log prefix' do
      expect(logger).to receive(default_log_level).with("#{default_log_prefix}: #{message}")
      subject.send :log, message
    end

    it 'uses configured log prefix' do
      log_prefix = 'Flibby'
      allow(subject).to receive(:log_prefix).and_return(log_prefix)
      expect(logger).to receive(default_log_level).with("#{log_prefix}: #{message}")
      subject.send :log, message
    end

    it 'defaults log level to :info' do
      expect(logger).to receive(default_log_level)
      subject.send :log, message
    end

    it 'allows other log levels' do
      log_level = :warn
      expect(logger).to receive(log_level)
      subject.send :log, message, level: log_level
    end

    describe '#shutdown' do
      before(:each) do
        allow(channel).to receive(:close)
        allow(connection).to receive(:close)
        allow(subject).to receive(:connection).and_return(connection)
        allow(subject).to receive(:channel).and_return(channel)
        allow(subject).to receive(:log)
      end

      it 'logs shutting down' do
        expect(subject).to receive(:log).with('Shutting down')
        subject.shutdown
      end

      it 'closes the channel' do
        expect(channel).to receive(:close)
        subject.shutdown
      end

      it 'closes owned connection' do
        subject.instance_variable_set('@own_connection', true)
        expect(connection).to receive(:close)
        subject.shutdown
      end

      it 'does not close shared connection' do
        subject.instance_variable_set('@own_connection', false)
        expect(connection).not_to receive(:close)
        subject.shutdown
      end

      it 'does not try to shutdown if already shutdown' do
        subject.instance_variable_set('@shutdown', true)
        expect(channel).not_to receive(:close)
        expect(connection).not_to receive(:close)
        subject.shutdown
      end
    end # describe '#shutdown'

  end # describe 'instance'
end
