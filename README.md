# WhenCommitted

Provides `#when_commited` to run instance-specific code in an ActiveRecord
`#after_commit` callback.

This is very useful for things like enqueuing a background job that is triggered
by a model changing state. Usually, it is not sufficient to enqueue the job in
an `#after_save` hook, because there is always the chance that the save will be
rolled back (or that the job gets picked up before the save is committed). You
could try moving that code to an `after_commit` callback, but then you do not
have access to the `#changes` to your model (they have already been applied), so
it may be difficult to make decisions on whether to enqueue the job or not.

It can also be useful for running some code in the same process, but outside of
the current transaction.

## Usage

Include the WhenCommitted::ActiveRecord module in your model:

    class Post < ActiveRecord::Base
      include WhenCommitted::ActiveRecord
    end

Call `#when_committed` with a block of code that should run when the transaction
is committed:

    def update_score(new_score)
      self.score = new_score
      when_committed { Resque.enqueue(RecalculateAggregateScores, self.id) }
      self.score_changed = true
    end

By default, `when_committed` will raise an exception if it is called outside
of an ActiveRecord transaction, since the block would never be run.
If you need it to also be able to run outside of a transaction (e.g. if you
have multiple callsites - some in a transaction, some not), specify the
`run_now_if_no_transaction: true` argument.


    def update_score(new_score)
      self.score = new_score
      when_committed(run_now_if_no_transaction: true) {
        Resque.enqueue(RecalculateAggregateScores, self.id)
      }
      self.score_changed = true
    end

Be aware that when using this argument, the order of execution changes
depending on if a transaction is present or not. When a transaction is present,
`score` will be set, then `score_changed` is set, then eventually the Resque
call is made when the transaction commits. When a transaction is not present,
`score` will be set, then the Resque call is made, then `score_changed` is set.

## Installation

Add this line to your application's Gemfile:

    gem 'when_committed', github: 'ShippingEasy/when_committed'

And then execute:

    $ bundle

## Contributing

1. [Fork it](https://github.com/ShippingEasy/when_committed/fork_select)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. [Create new Pull Request](https://github.com/ShippingEasy/when_committed/pull/new/master)
