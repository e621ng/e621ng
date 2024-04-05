# frozen_string_literal: true

FactoryBot.define do
  factory(:mod_action) do
    creator :factory => :user
    action { "1234" }
    values { {a: 'b'} }
  end
end
