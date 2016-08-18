require "sneakers_exponential_retry/version"

class ExponentialRetry
  MINUTE = 60 * 1000
  DEFAULT_MAX_RETRY_COUNT = 14

  def initialize(channel, queue, opts)
    @channel = channel
    @max_retry_count = calculate_max_retry_count(opts)
    @retry_exchange = create_retry_exchange(queue.name)
    @logger = opts[:handler_options] ? opts[:handler_options][:logger] : nil

    create_retry_queue(queue.name, opts[:exchange])
      .bind(@retry_exchange, :routing_key => '#')
  end

  def calculate_max_retry_count opts
    handler_options = opts[:handler_options] || {}
    ( handler_options[:max_retry_count] || DEFAULT_MAX_RETRY_COUNT ).to_i
  end
  private :calculate_max_retry_count

  def create_retry_exchange queue_name
    @channel.exchange("#{queue_name}-retry-ex",
                      :type => 'topic',
                      :durable => true)
  end
  private :create_retry_exchange

  def create_retry_queue queue_name, exchange_name
    @channel.queue(
      "#{queue_name}-retry-queue",
      durable: true,
      arguments: {
        :'x-dead-letter-exchange' => exchange_name
      }
    )
  end
  private :create_retry_queue

  def acknowledge(hdr, props, msg)
    @channel.acknowledge(hdr.delivery_tag, false)
  end

  def reject(hdr, props, msg, requeue=false)
    @channel.reject(hdr.delivery_tag, requeue)
  end

  def error(hdr, props, msg, err)
    handle_failing_message(hdr, props, msg, err)
  end

  def handle_failing_message hdr, props, msg, error
    retry_count = get_retry_count(props[:headers])
    if retry_count >= @max_retry_count
      reject(hdr, props, msg)
      return
    end


    @retry_exchange.publish(msg,
                            :headers => {
                              'retry-count' => retry_count + 1
                            },
                            :routing_key => hdr.routing_key,
                            :expiration => expiration_time(retry_count))
    log_retry(retry_count)
    acknowledge(hdr, props, msg)
  end
  private :handle_failing_message

  def log_retry count
    return unless @logger
    @logger.info do
      "retry_count: #{count + 1}"
    end
  end
  private :log_retry

  def get_retry_count headers
    return 0 unless headers
    headers['retry-count'].to_i
  end
  private :get_retry_count

  def expiration_time retry_count
    (2 ** retry_count) * MINUTE
  end
  private :expiration_time

  def timeout(hdr, props, msg)
    reject(hdr, props, msg)
  end

  def noop(hdr, props, msg)
  end
end
