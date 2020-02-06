# Changelog

## 1.0.0

* Add a dependency on active_record >= 5.1
* Add no_op `before_committed!` and `add_to_transaction` methods to `WhenCommitted::CallbackRecord` for Rails 5.1 compatibility
  The `ActiveRecord::ConnectionAdapters::Transaction` API changed to now expect "record-like" objects to respond to these methodsß
* Update `committed!` to accept keyword arguments for Rails 5.1 compatibility
