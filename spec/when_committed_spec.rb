require 'active_record'
require 'when_committed'

describe "WhenCommitted" do
  before(:all) do
    ActiveRecord::Base.establish_connection :adapter => :sqlite3,
                                            :database => ":memory:"
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table(:widgets) do |t|
        t.string  :name
        t.integer :size
      end

      create_table(:samples) do |t|
        t.string :name
      end
    end
  end

  it "provides a #when_committed method" do
    sample_class = Sample
    model = sample_class.new
    model.should_not respond_to(:when_committed)
    sample_class.send :include, WhenCommitted::ActiveRecord
    model.should respond_to(:when_committed)
  end

  describe "#when_committed(run_now_if_no_transaction: true)" do
    before do
      Backgrounder.reset
    end
    let(:model) { Widget.new }

    context "when not running within a transaction" do
      it "runs the block immediately" do
        model.needs_to_happen
        Backgrounder.jobs.should == [:important_work]
      end
    end

    context "when running within a transaction" do
      it "does not run the provided block until the transaction is committed" do
        Widget.transaction do
          model.needs_to_happen
          Backgrounder.jobs.should be_empty
          model.save
          Backgrounder.jobs.should be_empty
        end
        Backgrounder.jobs.should == [:important_work]
      end

      it "runs the provided block, even if the model itself doesn't commit any changes" do
        Widget.transaction do
          model.needs_to_happen
          Backgrounder.jobs.should be_empty
        end
        Backgrounder.jobs.should == [:important_work]
      end
    end
  end

  describe "#when_committed" do
    before do
      Backgrounder.reset
    end
    let(:model) { Widget.new }

    context "when not running within a transaction" do
      it "raises an exception" do
        expect {
          model.action_that_needs_follow_up_after_commit
        }.to raise_error(WhenCommitted::RequiresTransactionError, /run_now_if_no_transaction/)
      end
    end

    it "does not run the provided block until the transaction is committed" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        Backgrounder.jobs.should be_empty
        model.save
        Backgrounder.jobs.should be_empty
      end
      Backgrounder.jobs.should == [:important_work]
    end

    it "does not run the provided block if the transaction is rolled back" do
      begin
        Widget.transaction do
          model.action_that_needs_follow_up_after_commit
          model.save
          raise Catastrophe
        end
      rescue Catastrophe
      end
      Backgrounder.jobs.should be_empty
    end

    it "allows you to register multiple after_commit blocks" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.another_action_with_follow_up
        model.save
      end
      Backgrounder.jobs.should == [:important_work,:more_work]
    end

    it "runs the provided block, even if the model itself doesn't commit any changes" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        Backgrounder.jobs.should be_empty
      end
      Backgrounder.jobs.should == [:important_work]
    end

    it "does not run a registered block more than once" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.save
      end
      Widget.transaction do
        model.name = "changed"
        model.save
      end
      Backgrounder.should have(1).job
    end

    describe "nested transactions" do
      it "runs the provided block once, after the outer transaction is committed" do
        # add extra layer just to prove it works at any level of nesting
        Widget.transaction do
          Widget.transaction do
            model.action_that_needs_follow_up_after_commit
            Widget.transaction(requires_new: true) do
              model.another_action_with_follow_up
            end
            Backgrounder.jobs.should == []
          end
        end
        Backgrounder.jobs.should == [:important_work, :more_work]
      end

      it "does not run the block if it is defined in a nested transaction that is rolled back" do
        Widget.transaction do
          model.action_that_needs_follow_up_after_commit
          Widget.transaction(requires_new: true) do
            model.another_action_with_follow_up
            raise ActiveRecord::Rollback
          end
          Backgrounder.jobs.should == []
        end
        Backgrounder.jobs.should == [:important_work]
      end

      it "does not run the block from inner or outer transaction if exception raised in inner block" do
        begin
          Widget.transaction do
            model.action_that_needs_follow_up_after_commit
            Widget.transaction(requires_new: true) do
              model.another_action_with_follow_up
              raise Catastrophe
            end
            Backgrounder.jobs.should == []
          end
        rescue
        end
        Backgrounder.jobs.should == []
      end

      it "does not run the block from inner or outer transaction if exception raised in outer block" do
        begin
          Widget.transaction do
            model.action_that_needs_follow_up_after_commit
            Widget.transaction(requires_new: true) do
              model.another_action_with_follow_up
            end
            raise Catastrophe
          end
        rescue
        end
        Backgrounder.jobs.should == []
      end
    end

    context "when a previous callback raised an exception" do
      it "does not run the block" do
        w1 = Widget.new
        w2 = Widget.new
        w3 = Widget.new
        w4 = Widget.new

        expect {
          Widget.transaction do
            w1.when_committed { Backgrounder.enqueue :first }
            w2.when_committed { raise Catastrophe }
            w3.when_committed { Backgrounder.enqueue :third }
            w4.when_committed { Backgrounder.enqueue :fourth }
          end
        }.to raise_error(Catastrophe)

        Backgrounder.jobs.should == [:first]
      end
    end
  end
end

class Sample < ActiveRecord::Base
end

class Widget < ActiveRecord::Base
  include WhenCommitted::ActiveRecord
  def action_that_needs_follow_up_after_commit
    when_committed { Backgrounder.enqueue :important_work }
  end
  def needs_to_happen
    when_committed(run_now_if_no_transaction: true) { Backgrounder.enqueue :important_work }
  end
  def another_action_with_follow_up
    when_committed { Backgrounder.enqueue :more_work }
  end
end

class Backgrounder
  def self.enqueue job
    jobs << job
  end

  def self.jobs
    @jobs ||= []
  end

  def self.reset
    @jobs = []
  end
end

class Catastrophe < StandardError; end
