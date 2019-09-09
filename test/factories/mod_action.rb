FactoryBot.define do
  factory(:mod_action) do
    creator :factory => :user
    action { "1234" }
    category { 3 }
    values { {a: 'b'} }
  end
end
