# frozen_string_literal: true

class AddTrgmIndexToTagAliasesAntecedentName < ActiveRecord::Migration[8.1]
  def up
    TagAlias.without_timeout do
      execute <<~SQL.squish
        CREATE INDEX index_tag_aliases_on_antecedent_name_trgm
            ON tag_aliases
            USING gin (antecedent_name gin_trgm_ops)
            WHERE status IN ('active', 'processing', 'queued')
      SQL
    end
  end

  def down
    TagAlias.without_timeout do
      execute <<~SQL.squish
        DROP INDEX index_tag_aliases_on_antecedent_name_trgm
      SQL
    end
  end
end
