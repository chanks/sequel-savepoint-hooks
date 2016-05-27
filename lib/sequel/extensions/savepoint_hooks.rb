# frozen_string_literal: true

require 'sequel/extensions/savepoint_hooks/version'

module Sequel
  module SavepointHooks
    private

    def _transaction(conn, opts=Sequel::OPTS)
      if (t = _trans(conn)) && t[:hooks].last == :savepoint
        opts = {:hooks=>true}.merge(opts)
      end

      super(conn, opts)
    end

    def transaction_options(conn, opts)
      hash = super

      if t = _trans(conn)
        t[:hooks].push opts[:hooks]
      else
        hash[:hooks] = [opts[:hooks]]
      end

      hash
    end

    def transaction_finished?(conn)
      _trans(conn)[:hooks].pop
      super
    end

    def add_transaction_hook(conn, type, block)
      t = _trans(conn)
      current_level = savepoint_level(conn)
      hook_setting = t[:hooks][current_level - 1]

      return if hook_setting == false
      level_to_add = hook_setting == true ? current_level : 1

      all_hooks = t[type] ||= {}
      level_hooks = all_hooks[level_to_add] ||= []
      level_hooks << block
    end

    def transaction_hooks(conn, committed)
      t = _trans(conn)
      level = savepoint_level(conn)

      after_commit_hooks   = (ac = t[:after_commit])   && ac.delete(level)
      after_rollback_hooks = (ar = t[:after_rollback]) && ar.delete(level)

      committed ? after_commit_hooks : after_rollback_hooks
    end
  end

  Database.register_extension(:savepoint_hooks) { |db| db.extend(Sequel::SavepointHooks) }
end
