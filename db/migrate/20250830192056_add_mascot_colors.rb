# frozen_string_literal: true

class AddMascotColors < ActiveRecord::Migration[7.1]
  def up
    add_column :mascots, :foreground_color, :string, null: false, default: "#0f0f0f80"
    change_column_default :mascots, :background_color, "#012e57"
  end

  def down
    remove_column :mascots, :foreground_color
    change_column_default :mascots, :background_color, nil
  end
end
