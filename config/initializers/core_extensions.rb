# frozen_string_literal: true

module Danbooru
  module Extensions
    module String
      def to_escaped_for_sql_like
        gsub(/%|_|\*|\\\*|\\\\|\\/) do |str|
          case str
          when '%'    then '\%'
          when '_'    then '\_'
          when '*'    then '%'
          when '\*'   then '*'
          when '\\\\' then '\\\\'
          when '\\'   then '\\\\'
          end
        end
      end

      def truthy?
        match?(/\A(?>true|t|yes|y|on|1)\z/i)
      end

      def falsy?
        match?(/\A(?>false|f|no?|off|0)\z/i)
      end

      def to_bool_or_self
        # # if (m = match(/\A(?>(true|t|yes|y|on|1)|false|f|no|n|off|0)\z/i)).nil?
        # match(/\A((?>false|f|no|n|off|0)\z)?((?(1)\z|(?>true|t|yes|y|on|1)\z))/i)&.match(2)&.length&.send(:>, 0)
        return true if truthy?
        return false if falsy?
        self
      end
    end
  end
end

class String
  include Danbooru::Extensions::String
end
