# frozen_string_literal: true

require 'spec_helper'

describe Sequel::SavepointHooks do
  before do
    @db = Sequel.mock
    @db.extension :savepoint_hooks
    @hooks = []
  end

  describe "when transactions are opened without any special arguments" do
    it "transactions should work as expected" do
      @db.transaction do
        @db.execute "foo"
      end

      assert_equal ["BEGIN", "foo", "COMMIT"], @db.sqls
    end

    it "savepoints should work as expected" do
      @db.transaction do
        @db.transaction(savepoint: true) do
          @db.execute "foo"
        end
      end

      assert_equal ["BEGIN", "SAVEPOINT autopoint_1", "foo", "RELEASE SAVEPOINT autopoint_1", "COMMIT"], @db.sqls
    end

    it "after_commit should behave normally" do
      @db.transaction do
        @db.after_commit { @hooks << :commit1 }
        @db.transaction(savepoint: true) { @db.after_commit { @hooks << :commit2} }
        @db.after_commit { @hooks << :commit3 }
        @db.transaction(savepoint: true) { @db.after_commit { @hooks << :commit4 } }
        @db.after_commit { @hooks << :commit5 }

        assert_equal [], @hooks
      end

      assert_equal [:commit1, :commit2, :commit3, :commit4, :commit5], @hooks
    end
  end

  describe "when a transaction is opened with hooks: true" do
    it "should trigger after_commit hooks as normal" do
      @db.transaction hooks: true do
        @db.after_commit   { @hooks << :commit   }
        @db.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks
      end

      assert_equal [:commit], @hooks
    end

    it "should trigger after_rollback hooks as normal" do
      @db.transaction hooks: true do
        @db.after_commit   { @hooks << :commit   }
        @db.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks

        raise Sequel::Rollback
      end

      assert_equal [:rollback], @hooks
    end
  end

  describe "when a transaction is opened with hooks: false" do
    it "should not trigger after_commit hooks" do
      @db.transaction hooks: false do
        @db.after_commit   { @hooks << :commit   }
        @db.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks
      end

      assert_equal [], @hooks
    end

    it "should not trigger after_rollback hooks" do
      @db.transaction hooks: false do
        @db.after_commit   { @hooks << :commit   }
        @db.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks

        raise Sequel::Rollback
      end

      assert_equal [], @hooks
    end
  end

  describe "when a savepoint is opened with hooks: true" do
    it "should trigger after_commit hooks" do
      @db.transaction do
        @db.after_commit   { @hooks << :commit1   }
        @db.after_rollback { @hooks << :rollback1 }

        @db.transaction savepoint: true, hooks: true do
          @db.after_commit   { @hooks << :commit2   }
          @db.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        @db.transaction savepoint: true do
          @db.after_commit   { @hooks << :commit3   }
          @db.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2], @hooks
      end

      assert_equal [:commit2, :commit1, :commit3], @hooks
    end

    it "should trigger after_rollback hooks" do
      @db.transaction do
        @db.after_commit   { @hooks << :commit1   }
        @db.after_rollback { @hooks << :rollback1 }

        @db.transaction savepoint: true, hooks: true do
          @db.after_commit   { @hooks << :commit2   }
          @db.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks

          raise Sequel::Rollback
        end

        assert_equal [:rollback2], @hooks

        @db.transaction savepoint: true do
          @db.after_commit   { @hooks << :commit3   }
          @db.after_rollback { @hooks << :rollback3 }

          assert_equal [:rollback2], @hooks

          raise Sequel::Rollback
        end

        assert_equal [:rollback2], @hooks
        raise Sequel::Rollback
      end

      assert_equal [:rollback2, :rollback1, :rollback3], @hooks
    end

    it "should not retain hooks when leaving and then reentering a transaction nesting level" do
      @db.transaction hooks: true do
        @db.after_commit { @hooks << :commit1 }

        @db.transaction savepoint: true, hooks: true do
          @db.after_commit { @hooks << :commit2 }
          assert_equal [], @hooks
        end

        @db.after_commit { @hooks << :commit3 }

        @db.transaction savepoint: true, hooks: true do
          @db.after_commit { @hooks << :commit4 }
          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit4], @hooks

        @db.after_commit { @hooks << :commit5 }

        @db.transaction savepoint: true do
          @db.after_commit { @hooks << :commit6 }
          assert_equal [:commit2, :commit4], @hooks
        end

        assert_equal [:commit2, :commit4], @hooks
      end

      assert_equal [:commit2, :commit4, :commit1, :commit3, :commit5, :commit6], @hooks
    end
  end

  describe "when a transaction is opened with hooks: :savepoint" do
    it "should open savepoints inside the transaction with callbacks" do
      @db.transaction hooks: :savepoint do
        @db.after_commit   { @hooks << :commit1   }
        @db.after_rollback { @hooks << :rollback1 }

        @db.transaction savepoint: true do
          @db.after_commit   { @hooks << :commit2   }
          @db.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        @db.transaction savepoint: true do
          @db.after_commit   { @hooks << :commit3   }
          @db.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit3], @hooks
      end

      assert_equal [:commit2, :commit3, :commit1], @hooks
    end

    it "should support being overridden with :hooks=>false" do
      @db.transaction hooks: :savepoint do
        @db.after_commit { @hooks << :commit1 }
        @db.transaction savepoint: true, hooks: false do
          @db.after_commit { @hooks << :commit2 }
        end
        assert_equal [], @hooks
        @db.after_commit { @hooks << :commit3 }
        assert_equal [], @hooks
      end

      assert_equal [:commit1, :commit3], @hooks
    end

    it "should support being overridden with :hooks=>:savepoint" do
      @db.transaction hooks: :savepoint do
        @db.after_commit { @hooks << :commit1 }

        @db.transaction savepoint: true, hooks: :savepoint do
          @db.after_commit { @hooks << :commit2 }

          @db.transaction savepoint: true do
            @db.after_commit { @hooks << :commit3 }
          end

          assert_equal [:commit3], @hooks
        end

        assert_equal [:commit3], @hooks
      end

      assert_equal [:commit3, :commit1, :commit2], @hooks
    end

    it "should play well with :auto_savepoint" do
      @db.transaction auto_savepoint: true, hooks: :savepoint do
        @db.after_commit   { @hooks << :commit1   }
        @db.after_rollback { @hooks << :rollback1 }

        @db.transaction do
          @db.after_commit   { @hooks << :commit2   }
          @db.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        @db.transaction do
          @db.after_commit   { @hooks << :commit3   }
          @db.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit3], @hooks
      end

      assert_equal [:commit2, :commit3, :commit1], @hooks
    end
  end
end
