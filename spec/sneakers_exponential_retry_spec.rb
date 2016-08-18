require 'spec_helper'

describe SneakersExponentialRetry do
  let(:channel) do
    double(:channel, :exchange => mock_retry_exchange,
                     :queue => mock_retry_queue)
  end
  let(:mock_retry_queue) { double(:mock_retry_queue, bind: true) }
  let(:mock_retry_exchange) { double(:mock_retry_exchange) }

  let(:queue) { double(:queue, name: 'the-queue-name') }
  let(:opts) do
    {
      exchange: 'the-original-exchange-name'
    }
  end

  describe '::new(channel, queue, opts)' do
    it 'creates a retry exchange' do
      expect(channel).to receive(:exchange).with(
        "#{queue.name}-retry-ex",
        type: 'topic',
        durable: true
      )
      ExponentialRetry.new(channel, queue, opts)
    end

    it 'creates a retry queue' do
      expect(channel).to receive(:queue).with(
        "#{queue.name}-retry-queue",
        durable: true,
        arguments: {
          :'x-dead-letter-exchange' => opts[:exchange]
        }
      )
      ExponentialRetry.new(channel, queue, opts)
    end

    it 'binds the retry queue with the retry exchange' do
      expect(mock_retry_queue).to receive(:bind).with(
        mock_retry_exchange,
        routing_key: '#'
      )
      ExponentialRetry.new(channel, queue, opts)
    end
  end

  describe '#error(hdr, props, msg, err)' do
    let(:props) { { headers: {} } }
    let(:hdr) do
      double(:hdr,
        delivery_tag: 'the-delivery-tag',
        routing_key: 'the.routing.key')
    end
    let(:msg) { "the-message" }
    let(:err) { nil }
    let(:handler) { ExponentialRetry.new(channel, queue, opts) }
    let(:logger) { double(:logger, info: nil) }

    before :each do
      allow(mock_retry_exchange).to receive(:publish)
      allow(channel).to receive(:acknowledge)
    end

    shared_examples "retry_error_behaviors" do |options|
      retry_count = options[:retry_count]

      it 'publish the message via retry exchange with retry-count and expiration' do
        expect(mock_retry_exchange).to receive(:publish).with(msg, {
          headers: {
            'retry-count' => retry_count + 1
          },
          routing_key: hdr.routing_key,
          expiration: (2 ** retry_count) * ExponentialRetry::MINUTE
        })
        handler.error(hdr, props, msg, err)
      end
      it 'acknowledge the message' do
        expect(channel).to receive(:acknowledge).with(hdr.delivery_tag, false)
        handler.error(hdr, props, msg, err)
      end
      it 'logs the retry' do
        opts[:handler_options] = { logger: logger }
        expect(logger).to receive(:info) do |&block|
          msg = block.call
          expect(msg).to eq("retry_count: #{retry_count + 1}")
        end
        handler.error(hdr, props, msg, err)
      end
    end

    context "if not retried yet" do
      include_examples "retry_error_behaviors", retry_count: 0
    end

    context "if having been retried" do
      before :each do
        props[:headers]['retry-count'] = 3
      end
      include_examples "retry_error_behaviors", retry_count: 3
    end

    context "if retry-count reaches the given max_retry_count" do
      let(:max_retry_count) { 10 }
      let(:handler) do
        ExponentialRetry.new(channel, queue, {
          handler_options: {
            max_retry_count: max_retry_count
          }
        })
      end
      before :each do
        props[:headers]['retry-count'] = max_retry_count
        allow(channel).to receive(:reject)
      end

      it 'rejects the message' do
        expect(channel).to receive(:reject).with(hdr.delivery_tag, false)
        expect(mock_retry_exchange).not_to receive(:publish)
        handler.error(hdr, props, msg, err)
      end
    end
  end

  shared_examples "delegating_behaviors" do |opts|
    let(:props) { { headers: {} } }
    let(:hdr) { double(:hdr, delivery_tag: 'the-delivery-tag') }
    let(:msg) { "the-message" }
    let(:err) { nil }
    let(:handler) { ExponentialRetry.new(channel, queue, opts) }
    it 'delegate to channel' do
      expect(channel).to receive(opts[:delegate]).with(hdr.delivery_tag, false)
      handler.public_send(opts[:method_name], hdr, props, msg)
    end
  end

  describe '#acknowledge(hdr, props, msg)' do
    include_examples "delegating_behaviors", {
      method_name: :acknowledge,
      delegate: :acknowledge
    }
  end

  describe '#reject(hdr, props, msg)' do
    include_examples "delegating_behaviors", {
      method_name: :reject,
      delegate: :reject
    }
  end

  describe '#timeout(hdr, props, msg)' do
    include_examples "delegating_behaviors", {
      method_name: :timeout,
      delegate: :reject
    }
  end
end
