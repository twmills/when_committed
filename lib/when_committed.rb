require 'when_committed/version'

module WhenCommitted
  module ActiveRecord
    def when_committed(run_now_if_no_transaction: false, &block)
      cn = self.class.connection
      if cn.current_transaction.open?
        cb = CallbackRecord.new(cn, &block)
        cn.add_transaction_record(cb)
      else
        if run_now_if_no_transaction
          block.call
        else
          raise RequiresTransactionError
        end
      end
    end
  end

  # Adheres to the "record" duck type expected by the `add_record` method on
  # ActiveRecord::ConnnectionAdapters::Transaction
  # https://github.com/rails/rails/blob/5-1-stable/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb
  class CallbackRecord
    def initialize(connection, &callback)
      @connection = connection
      @callback = callback
    end

    def committed!(should_run_callbacks: true, **)
      # should_run_callbacks will only be false if we're in the process of
      # raising an exception (caused by another callback) and AR is giving us
      # a chance to clean up any internal state.
      # We should be consistent with ActiveRecord and *not* run the remaining
      # callbacks>
      if should_run_callbacks
        @callback.call
      end
    end

    def rolledback!(*)
    end

    def before_committed!(*)
    end

    def add_to_transaction(*)
      # The current transaction is resolving without handling this record, so
      # pass it up to the parent transaction instead.
      @connection.add_transaction_record(self)
    end

    def trigger_transactional_callbacks?
      # This method is meant to be a check whether the record has been persisted
      # or destroyed, and if those callbacks need to be run. That doesn't apply
      # here, so always return true.
      true
    end
  end

  class RequiresTransactionError < StandardError
    HELP = "Specify `run_now_if_no_transaction: true` if you want to allow the block to run immediately when there is no transaction.".freeze

    def initialize(message=nil, *args)
      super(message||HELP, *args)
    end
  end
end
