# frozen_string_literal: true

require "rails_helper"

RSpec.describe SensitiveParams do
  describe "Rails parameter filtering" do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    it "filters the exact and partial matches" do
      filtered = filter.filter("key" => "secret", "api_key" => "secret", "password" => "secret")
      expect(filtered.values).to all(eq("[FILTERED]"))
    end

    it "does not filter names that merely contain an exact-match param" do
      filtered = filter.filter("uid" => "3", "monkey" => "banana", "keyword" => "x")
      expect(filtered).to eq("uid" => "3", "monkey" => "banana", "keyword" => "x")
    end
  end

  describe ".to_datadog_regex" do
    def obfuscate(url)
      Datadog::Tracing::Contrib::Utils::Quantization::HTTP.url(url, query: { obfuscate: { regex: described_class.to_datadog_regex } })
    end

    it "redacts key when it is the first parameter" do
      url = obfuscate("/maintenance/user/password_reset/edit?key=SECRET&uid=3")
      expect(url).not_to include("SECRET")
      expect(url).to include("uid=3")
    end

    it "redacts key after another parameter and keeps the separator" do
      url = obfuscate("/maintenance/user/password_reset/edit?uid=3&key=SECRET")
      expect(url).not_to include("SECRET")
      expect(url).to include("uid=3&")
    end

    it "still redacts partial matches" do
      expect(obfuscate("/posts?api_key=SECRET&login=a")).not_to include("SECRET")
    end

    it "does not redact names that merely end in key" do
      expect(obfuscate("/posts?monkey=banana")).to include("monkey=banana")
    end
  end
end
