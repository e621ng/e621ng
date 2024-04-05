# frozen_string_literal: true

class PostReportReason < ApplicationRecord
  belongs_to_creator
  validates :reason, uniqueness: { case_sensitive: false }


  def self.for_select
    reasons = order('id DESC')
    reasons = reasons.map {|x| [x.reason, x.id]}
    reasons.unshift ['', '']
  end

  def self.for_select_descriptions
    reasons = self.order('id DESC')
    js_map = {}
    reasons.each {|x| js_map[x.id] = x.description}
    js_map
  end
end
