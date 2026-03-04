# frozen_string_literal: true

module Sources
  module Alternates
    class Inkbunny < Base
      def force_https?
        true
      end

      def domains
        ["inkbunny.net", "metapix.net"]
      end

      def original_url
        # Remove anchor
        if @parsed_url.fragment.present?
          @parsed_url.fragment = nil
        end

        # Remove trailing dash
        if @parsed_url.path.present? && @parsed_url.path.end_with?("-")
          @parsed_url.path = @parsed_url.path.chomp("-")
        end

        id = id_from_submission
        return submission_url_from_id(id) if id

        @url = @parsed_url.to_s
      end

      private

      def submission_url_from_id(id)
        "https://inkbunny.net/s/#{id}"
      end

      def id_from_submission
        return nil unless parsed_url&.host == "inkbunny.net"

        if parsed_url.path == "/submissionview.php" && parsed_url.query_values.present? && parsed_url.query_values["id"].present?
          id = parsed_url.query_values["id"].to_i
          return nil if id <= 0

          if parsed_url.query_values["page"].present?
            page = parsed_url.query_values["page"].to_i
            return "#{id}-p#{page}" if page > 1
          end

          return id
        end

        nil
      end
    end
  end
end
