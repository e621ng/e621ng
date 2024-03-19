# frozen_string_literal: true

module TagsHelper
  def format_transitive_item(transitive)
    html = "<strong class=\"text-error\">#{transitive[0].to_s.titlecase}</strong> ".html_safe
    if transitive[0] == :alias
      html << "#{transitive[2]} -> #{transitive[3]} will become #{transitive[2]} -> #{transitive[4]}"
    else
      html << "#{transitive[2]} +> #{transitive[3]} will become #{transitive[4]} +> #{transitive[5]}"
    end
    html
  end
end
