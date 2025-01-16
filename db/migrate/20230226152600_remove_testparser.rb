# frozen_string_literal: true

class RemoveTestparser < ActiveRecord::Migration[7.0]
  def up
    execute "DROP TRIGGER trigger_posts_on_tag_index_update ON posts"
    remove_column :posts, :tag_index

    execute "DROP TEXT SEARCH CONFIGURATION danbooru"
    execute "DROP TEXT SEARCH PARSER testparser"
    %i[testprs_start testprs_lextype testprs_getlexeme testprs_end].each do |function|
      execute "DROP FUNCTION #{function}"
    end
  end
end
