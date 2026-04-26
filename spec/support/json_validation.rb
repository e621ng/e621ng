# frozen_string_literal: true

require "rspec/expectations"

# Allows easily testing JSON output for conformity.
#
# ### Parameters
# * `json_format` {`Hash`}: All valid JSON keys mapped to their value's type
# * `nullable_keys` {`Array`} [`[]`]: JSON keys that can be nil
# * `:root_type` {`Symbol` | `Class`} [`nil`]: The expected type of the root object (`actual`).
#    * `:array`/`Array`: Will fail if the given object isn't an `Array` of `Hash`es following the
#    format defined by `json_format`.
#    * `:object`/`:hash`/`Hash`: Will fail if the given object isn't a `Hash` following the format
#    defined by `json_format`.
#    * All other values will not enforce a strict type for the root object; it can be either a
#    `Hash` following the format defined by `json_format`, or an `Array` of such.
#
# Requires `json_format` to either be passed in or defined in the execution context via
# `let`/`let!`. `nullable_keys` can be defined the same way.
#
# Manually passing in a value for `json_format` & `nullable_keys` will use that while ignoring any
# `let`-defined alternatives. E.g. In cases like validating the `UserController` endpoints, where
# the results will have added/missing keys depending on the endpoint & if the requested user is the
# logged-in user, overriding the `let`-defined `json_format` with a `merge`d version manually passed
# in will work.
#
# Validated types:
# * `String`
# * `Numeric`
# * `Integer`
# * `IPAddr` (natively recognized by `parsed_body` somehow)
# * `Date` (manually parsed from `String` given by `parsed_body`)
# * `DateTime` (manually parsed from `String` given by `parsed_body`)
#
# TODO: * `optional_keys` {`Array`} [`[]`]: JSON keys that can be entirely omited from the response.
# TODO: Add support for typed arrays in `json_format`
RSpec.shared_context "validating JSON" do
  RSpec::Matchers.define :match_json_format do |json_format = nil, nullable_keys = nil, root_type: nil|
    define_method :validate_instance do |obj|
      json_format ||= self.json_format
      nullable_keys ||= self.nullable_keys || []

      expect(obj.keys).to match_array(json_format.keys.map(&:to_s))
      obj.each_pair do |k, val|
        key_sym = k.to_sym
        expected_type = json_format[key_sym]
        if expected_type.in?([Date, DateTime])
          expect { val = val.send(:"to_#{expected_type.name.downcase}") if val.is_a?(String) }.not_to raise_error
          expect(val).to be_a(expected_type) | (be_a(NilClass) & satisfy { |_v| expect(nullable_keys).to include(key_sym) })
        elsif nullable_keys.include?(key_sym)
          expect(val).to be_a(expected_type) | be_a(NilClass)
        else
          expect(val).to be_a(expected_type)
        end
      end
    end
    match(notify_expectation_failures: true) do |actual|
      case root_type
      when Array, :array
        expect(actual).to be_a(Array)
        actual.each { |e| validate_instance(e) }
      when Hash, :hash, :object
        expect(actual).to be_a(Hash)
        validate_instance(actual)
      else
        if actual.is_a?(Array)
          actual.each { |e| validate_instance(e) }
        else
          validate_instance(actual)
        end
      end
    end
  end
end
