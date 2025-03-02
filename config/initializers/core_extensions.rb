# frozen_string_literal: true

module Danbooru
  module Extensions
    module String
      def to_escaped_for_sql_like
        string = self.gsub(/%|_|\*|\\\*|\\\\|\\/) do |str|
          case str
          when '%'    then '\%'
          when '_'    then '\_'
          when '*'    then '%'
          when '\*'   then '*'
          when '\\\\' then '\\\\'
          when '\\'   then '\\\\'
          end
        end

        string
      end

      def truthy?
        self.match?(/\A(true|t|yes|y|on|1)\z/i)
      end

      def falsy?
        self.match?(/\A(false|f|no|n|off|0)\z/i)
      end
    end
  end
end

class String
  include Danbooru::Extensions::String
end
