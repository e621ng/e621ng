# frozen_string_literal: true

# Important:
#
# 139_backfill_replacement_sequence_number.rb MUST be run before this migration,
# or the NOT NULL constraint will fail.

class EnforcePostReplacementSequenceNumber < ActiveRecord::Migration[8.1]
  def change
    PostReplacement.without_timeout do
      change_column_null :post_replacements2, :sequence_number, false

      add_index :post_replacements2, %i[post_id sequence_number],
                unique: true,
                name: :index_post_replacements2_on_post_id_and_sequence_number

      add_check_constraint :post_replacements2,
                           "(status = 'original') = (sequence_number = 0)",
                           name: :post_replacements2_status_original_seq0
    end
  end
end
