# frozen_string_literal: true

class AddTrgmIndexToTagAliasesAntecedentName < ActiveRecord::Migration[8.1]
  def up
    TagAlias.without_timeout do
      add_index :tag_aliases, :antecedent_name,
                name: :index_tag_aliases_on_antecedent_name_trgm,
                using: :gin,
                opclass: :gin_trgm_ops,
                where: "status IN ('active', 'processing', 'queued')"
    end
  end

  def down
    TagAlias.without_timeout do
      remove_index :tag_aliases, name: :index_tag_aliases_on_antecedent_name_trgm, if_exists: true
    end
  end
end
