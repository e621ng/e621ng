# frozen_string_literal: true

require "rspec/expectations"

# Allows easily testing JSON output for conformity. Requires the following to either be passed in or
# defined in the execution context via `let`(/`let!`?):
# * `json_format` {`Hash`}: All valid JSON keys mapped to their value's type
# * `nullable_keys` {`Array`} [`[]`]: JSON keys that can be nil
#
# Manually passing in a value for the above will use that while ignoring any `let`-defined
# alternatives. E.g. In cases like validating the `UserController` endpoints, where the results will
# have added/missing keys depending on the endpoint & if the requested user is the logged-in user,
# overriding the `let`-defined `json_format` with a `merge`d version manually passed in will work.
#
# TODO: * `optional_keys` {`Array`} [`[]`]: JSON keys that can be entirely omited from the response.
# TODO: Add support for typed arrays in `json_format`
# IDEA: Allow explictly defining whether the root must be an array or a hash?
RSpec.shared_context "validating JSON" do
  RSpec::Matchers.define :match_json_format do |json_format, nullable_keys|
    define_method :validate_instance do |obj|
      json_format ||= self.json_format
      nullable_keys ||= self.nullable_keys || []

      expect(obj.keys).to match_array(json_format.keys.map(&:to_s))
      obj.each_pair do |k, val|
        key_sym = k.to_sym
        if json_format[key_sym] == Date
          expect { val.is_a?(String) ? val.to_date : val }.not_to raise_error
          expect(val.is_a?(String) ? val.to_date : val).to be_a(Date) | (be_a(NilClass) & satisfy { |_v| expect(nullable_keys).to include(key_sym) })
        elsif nullable_keys.include?(key_sym)
          expect(val).to be_a(json_format[key_sym]) | be_a(NilClass)
        else
          expect(val).to be_a(json_format[key_sym])
        end
      end
    end
    match(notify_expectation_failures: true) do |actual|
      if actual.is_a?(Array)
        actual.each { |e| validate_instance(e) }
      else
        validate_instance(actual)
      end
    end
  end
end
