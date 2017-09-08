# frozen_string_literal: true

require 'spec_helper'

describe Sequel::SavepointHooks do
  before do
    DB.sqls.clear
    @hooks = []
  end

  describe "when transactions are opened without any special arguments" do
    it "transactions should work as expected" do
      DB.transaction do
        DB.execute "foo"
      end

      assert_equal ["BEGIN", "foo", "COMMIT"], DB.sqls
    end

    it "savepoints should work as expected" do
      DB.transaction do
        DB.transaction(savepoint: true) do
          DB.execute "foo"
        end
      end

      assert_equal ["BEGIN", "SAVEPOINT autopoint_1", "foo", "RELEASE SAVEPOINT autopoint_1", "COMMIT"], DB.sqls
    end

    it "after_commit should behave normally" do
      DB.transaction do
        DB.after_commit { @hooks << :commit1 }
        DB.transaction(savepoint: true) { DB.after_commit { @hooks << :commit2} }
        DB.after_commit { @hooks << :commit3 }
        DB.transaction(savepoint: true) { DB.after_commit { @hooks << :commit4 } }
        DB.after_commit { @hooks << :commit5 }

        assert_equal [], @hooks
      end

      assert_equal [:commit1, :commit2, :commit3, :commit4, :commit5], @hooks
    end
  end

  describe "when a transaction is opened with hooks: true" do
    it "should trigger after_commit hooks as normal" do
      DB.transaction hooks: true do
        DB.after_commit   { @hooks << :commit   }
        DB.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks
      end

      assert_equal [:commit], @hooks
    end

    it "should trigger after_rollback hooks as normal" do
      DB.transaction hooks: true do
        DB.after_commit   { @hooks << :commit   }
        DB.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks

        raise Sequel::Rollback
      end

      assert_equal [:rollback], @hooks
    end
  end

  describe "when a transaction is opened with hooks: false" do
    it "should not trigger after_commit hooks" do
      DB.transaction hooks: false do
        DB.after_commit   { @hooks << :commit   }
        DB.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks
      end

      assert_equal [], @hooks
    end

    it "should not trigger after_rollback hooks" do
      DB.transaction hooks: false do
        DB.after_commit   { @hooks << :commit   }
        DB.after_rollback { @hooks << :rollback }

        assert_equal [], @hooks

        raise Sequel::Rollback
      end

      assert_equal [], @hooks
    end
  end

  describe "when a savepoint is opened with hooks: true" do
    it "should trigger after_commit hooks" do
      DB.transaction do
        DB.after_commit   { @hooks << :commit1   }
        DB.after_rollback { @hooks << :rollback1 }

        DB.transaction savepoint: true, hooks: true do
          DB.after_commit   { @hooks << :commit2   }
          DB.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        DB.transaction savepoint: true do
          DB.after_commit   { @hooks << :commit3   }
          DB.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2], @hooks
      end

      assert_equal [:commit2, :commit1, :commit3], @hooks
    end

    it "should trigger after_rollback hooks" do
      DB.transaction do
        DB.after_commit   { @hooks << :commit1   }
        DB.after_rollback { @hooks << :rollback1 }

        DB.transaction savepoint: true, hooks: true do
          DB.after_commit   { @hooks << :commit2   }
          DB.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks

          raise Sequel::Rollback
        end

        assert_equal [:rollback2], @hooks

        DB.transaction savepoint: true do
          DB.after_commit   { @hooks << :commit3   }
          DB.after_rollback { @hooks << :rollback3 }

          assert_equal [:rollback2], @hooks

          raise Sequel::Rollback
        end

        assert_equal [:rollback2], @hooks
        raise Sequel::Rollback
      end

      assert_equal [:rollback2, :rollback1, :rollback3], @hooks
    end

    it "should not retain hooks when leaving and then reentering a transaction nesting level" do
      DB.transaction hooks: true do
        DB.after_commit { @hooks << :commit1 }

        DB.transaction savepoint: true, hooks: true do
          DB.after_commit { @hooks << :commit2 }
          assert_equal [], @hooks
        end

        DB.after_commit { @hooks << :commit3 }

        DB.transaction savepoint: true, hooks: true do
          DB.after_commit { @hooks << :commit4 }
          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit4], @hooks

        DB.after_commit { @hooks << :commit5 }

        DB.transaction savepoint: true do
          DB.after_commit { @hooks << :commit6 }
          assert_equal [:commit2, :commit4], @hooks
        end

        assert_equal [:commit2, :commit4], @hooks
      end

      assert_equal [:commit2, :commit4, :commit1, :commit3, :commit5, :commit6], @hooks
    end
  end

  describe "when a transaction is opened with hooks: :savepoint" do
    it "should open savepoints inside the transaction with callbacks" do
      DB.transaction hooks: :savepoint do
        DB.after_commit   { @hooks << :commit1   }
        DB.after_rollback { @hooks << :rollback1 }

        DB.transaction savepoint: true do
          DB.after_commit   { @hooks << :commit2   }
          DB.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        DB.transaction savepoint: true do
          DB.after_commit   { @hooks << :commit3   }
          DB.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit3], @hooks
      end

      assert_equal [:commit2, :commit3, :commit1], @hooks
    end

    it "should support being overridden with :hooks=>false" do
      DB.transaction hooks: :savepoint do
        DB.after_commit { @hooks << :commit1 }
        DB.transaction savepoint: true, hooks: false do
          DB.after_commit { @hooks << :commit2 }
        end
        assert_equal [], @hooks
        DB.after_commit { @hooks << :commit3 }
        assert_equal [], @hooks
      end

      assert_equal [:commit1, :commit3], @hooks
    end

    it "should support being overridden with :hooks=>:savepoint" do
      DB.transaction hooks: :savepoint do
        DB.after_commit { @hooks << :commit1 }

        DB.transaction savepoint: true, hooks: :savepoint do
          DB.after_commit { @hooks << :commit2 }

          DB.transaction savepoint: true do
            DB.after_commit { @hooks << :commit3 }
          end

          assert_equal [:commit3], @hooks
        end

        assert_equal [:commit3], @hooks
      end

      assert_equal [:commit3, :commit1, :commit2], @hooks
    end

    it "should play well with :auto_savepoint" do
      DB.transaction auto_savepoint: true, hooks: :savepoint do
        DB.after_commit   { @hooks << :commit1   }
        DB.after_rollback { @hooks << :rollback1 }

        DB.transaction do
          DB.after_commit   { @hooks << :commit2   }
          DB.after_rollback { @hooks << :rollback2 }

          assert_equal [], @hooks
        end

        assert_equal [:commit2], @hooks

        DB.transaction do
          DB.after_commit   { @hooks << :commit3   }
          DB.after_rollback { @hooks << :rollback3 }

          assert_equal [:commit2], @hooks
        end

        assert_equal [:commit2, :commit3], @hooks
      end

      assert_equal [:commit2, :commit3, :commit1], @hooks
    end
  end
end
