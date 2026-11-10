# frozen_string_literal: true

# Rack applies these limits to urlencoded form bodies, but Rails parses GET query strings and JSON bodies itself and
# skips them. Apply the same limits everywhere. The values are Rack's own defaults.
module RequestLimits
  # Also caps every non-multipart request body, see Middleware::ParameterSanitizer.
  BYTESIZE_LIMIT = 4.megabytes
  PARAMS_LIMIT = 4096
  DEPTH_LIMIT = 32

  # Counts every hash entry and array element at any depth, like Rack counts every form pair
  # (`a[b]=1`, `ids[]=1`). Stops as soon as the limit is passed.
  def self.params_limit_exceeded?(data)
    count = 0
    stack = [data]
    until stack.empty?
      node = stack.pop
      children = case node
                 when Hash then node.values
                 when Array then node
                 else next
                 end
      count += children.size
      return true if count > PARAMS_LIMIT

      stack.concat(children)
    end
    false
  end
end

# Set explicitly rather than through RACK_* env vars, which Rack only reads when it is first loaded.
Rack::Utils.default_query_parser = Rack::QueryParser.make_default(
  RequestLimits::DEPTH_LIMIT,
  bytesize_limit: RequestLimits::BYTESIZE_LIMIT,
  params_limit: RequestLimits::PARAMS_LIMIT,
)

# GET query strings. Rails' default depth is 100.
ActionDispatch::ParamBuilder.default = ActionDispatch::ParamBuilder.make_default(RequestLimits::DEPTH_LIMIT)

ActionDispatch::QueryParser.singleton_class.prepend(Module.new do
  def each_pair(query_string, separator = nil)
    return super unless block_given?
    return super if separator.present? && separator != "&"

    query_string ||= ""
    if query_string.bytesize > RequestLimits::BYTESIZE_LIMIT
      raise Rack::QueryParser::QueryLimitError, "total query size exceeds limit (#{RequestLimits::BYTESIZE_LIMIT})"
    end

    params_count = query_string.empty? ? 0 : query_string.count("&") + 1
    if params_count > RequestLimits::PARAMS_LIMIT
      raise Rack::QueryParser::QueryLimitError, "total number of query parameters (#{params_count}) exceeds limit (#{RequestLimits::PARAMS_LIMIT})"
    end

    super
  end
end)

# JSON bodies. The body size is already capped by Middleware::ParameterSanitizer.
ActionDispatch::Request.parameter_parsers = ActionDispatch::Request.parameter_parsers.merge(
  json: ->(raw_post) do
    data = ActiveSupport::JSON.decode(raw_post, max_nesting: RequestLimits::DEPTH_LIMIT)

    if RequestLimits.params_limit_exceeded?(data)
      raise Rack::QueryParser::QueryLimitError, "total number of parameters exceeds limit (#{RequestLimits::PARAMS_LIMIT})"
    end

    data.is_a?(Hash) ? data : { _json: data }
  end,
)
