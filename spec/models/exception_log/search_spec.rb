# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ExceptionLog Search                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ExceptionLog do
  include_context "as admin"

  def make_log(overrides = {})
    create(:exception_log, **overrides)
  end

  # Shared fixtures used across most search param tests.
  let!(:log_a) { make_log(class_name: "RuntimeError",  version: "aaa0001") }
  let!(:log_b) { make_log(class_name: "ArgumentError", version: "bbb0002") }

  # ---------------------------------------------------------------------------
  # user_name param
  # ---------------------------------------------------------------------------

  describe "user_name param" do
    it "returns logs associated with the named user" do
      user      = create(:user)
      user_log  = make_log(user_id: user.id)
      other_log = make_log(user_id: nil)

      result = ExceptionLog.search(user_name: user.name)
      expect(result).to include(user_log)
      expect(result).not_to include(other_log)
    end

    it "returns all logs when user_name is absent" do
      result = ExceptionLog.search({})
      expect(result).to include(log_a, log_b)
    end
  end

  # ---------------------------------------------------------------------------
  # code param
  # ---------------------------------------------------------------------------

  describe "code param" do
    it "returns only the log matching the given UUID" do
      result = ExceptionLog.search(code: log_a.code)
      expect(result).to include(log_a)
      expect(result).not_to include(log_b)
    end

    it "returns no results when code does not match any record" do
      result = ExceptionLog.search(code: SecureRandom.uuid)
      expect(result).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # commit param
  # ---------------------------------------------------------------------------

  describe "commit param" do
    it "returns only logs matching the given version/commit hash" do
      result = ExceptionLog.search(commit: "aaa0001")
      expect(result).to include(log_a)
      expect(result).not_to include(log_b)
    end
  end

  # ---------------------------------------------------------------------------
  # class_name param
  # ---------------------------------------------------------------------------

  describe "class_name param" do
    it "returns only logs with the given class_name" do
      result = ExceptionLog.search(class_name: "RuntimeError")
      expect(result).to include(log_a)
      expect(result).not_to include(log_b)
    end
  end

  # ---------------------------------------------------------------------------
  # without_class_name param
  # ---------------------------------------------------------------------------

  describe "without_class_name param" do
    it "excludes logs with the given class_name" do
      result = ExceptionLog.search(without_class_name: "RuntimeError")
      expect(result).not_to include(log_a)
      expect(result).to include(log_b)
    end
  end
end
