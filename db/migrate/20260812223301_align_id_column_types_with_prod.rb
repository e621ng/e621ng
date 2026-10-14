# frozen_string_literal: true

# Aligns id column types with prod.
# structure.sql drifted to bigint on 12 tables where prod is integer - none of which will plausibly
# overflow - and to integer on dmails/uploads where prod is already bigint. Rather than rewriting
# large prod tables for no benefit, structure.sql adopts prod's types.
#
# Guarded by the column's current type, so every statement is a no-op on prod; only
# databases built from the drifted structure.sql (dev, CI) are converted. Fresh
# installs get the corrected types from the regenerated structure.sql directly.
class AlignIdColumnTypesWithProd < ActiveRecord::Migration[8.1]
  # structure.sql said bigint; prod is integer
  SHRINK = %i[
    blips exception_logs forum_categories help_pages post_report_reasons
    post_sets post_set_maintainers takedowns tag_type_versions tickets
    upload_whitelists user_statuses
  ].freeze

  # structure.sql said integer; prod is bigint
  WIDEN = %i[dmails uploads].freeze

  def up
    ApplicationRecord.without_timeout do
      SHRINK.each do |table|
        change_column table, :id, :integer if id_type(table) == "bigint"
      end
      WIDEN.each do |table|
        change_column table, :id, :bigint if id_type(table) == "integer"
      end
    end
  end

  def down
    # structure.sql is adopting prod's types; there is no prior state to restore.
  end

  private

  def id_type(table)
    connection.columns(table).find { |c| c.name == "id" }.sql_type
  end
end
