# frozen_string_literal: true

FactoryBot.define do
  factory :exception_log do
    class_name   { "RuntimeError" }
    message      { "something went wrong" }
    trace        { "app/foo.rb:10:in `bar'" }
    ip_addr      { "127.0.0.1" }
    version      { "abc1234" }
    code         { SecureRandom.uuid }
    extra_params { {} }
  end
end
