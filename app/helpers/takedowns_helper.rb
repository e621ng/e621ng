# frozen_string_literal: true

module TakedownsHelper
  def pretty_takedown_status(takedown)
    status = takedown.status.capitalize
    classes = {
      "inactive" => "background-grey",
      "denied" => "background-red",
      "partial" => "background-green",
      "approved" => "background-green",
    }
    tag.td(status, class: classes[takedown.status])
  end
end
