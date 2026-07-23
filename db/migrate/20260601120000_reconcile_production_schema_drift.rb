# Codifies schema objects that were applied directly to the production AND staging
# databases out-of-band (no migration, no schema_migrations record) — discovered
# 2026-06-01 while reconciling an uncommitted schema.rb dump against production:
#
#   - events.online            boolean, default false
#   - settings_id_key          UNIQUE INDEX on settings(id)   (redundant with the PK, but present in prod)
#   - settings_var_key         UNIQUE INDEX on settings(var)
#
# Idempotent on purpose: on prod/staging (which already have these) it is a no-op but
# still records this version, bringing those ledgers up to date; on fresh/dev/test
# databases it creates the objects so the schema reproduces production.
class ReconcileProductionSchemaDrift < ActiveRecord::Migration[5.2]
  def up
    add_column :events, :online, :boolean, default: false unless column_exists?(:events, :online)

    unless index_exists?(:settings, :id, name: "settings_id_key")
      add_index :settings, :id, unique: true, name: "settings_id_key"
    end

    unless index_exists?(:settings, :var, name: "settings_var_key")
      add_index :settings, :var, unique: true, name: "settings_var_key"
    end
  end

  def down
    remove_index :settings, name: "settings_var_key" if index_exists?(:settings, :var, name: "settings_var_key")
    remove_index :settings, name: "settings_id_key" if index_exists?(:settings, :id, name: "settings_id_key")
    remove_column :events, :online if column_exists?(:events, :online)
  end
end
