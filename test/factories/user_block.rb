# frozen_string_literal: true

FactoryBot.define do
  factory(:user_block) do
    target { create(:user) }
  end
end
