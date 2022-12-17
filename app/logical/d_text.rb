class DText
  def self.quote(message, creator_name)
    stripped_body = DText.strip_blocks(message, "quote")
    "[quote]\n#{creator_name} said:\n\n#{stripped_body}\n[/quote]\n\n"
  end

  def self.strip_blocks(string, tag)
    n = 0
    stripped = ""
    string = string.dup

    string.gsub!(/\s*\[#{tag}\](?!\])\s*/mi, "\n\n[#{tag}]\n\n")
    string.gsub!(/\s*\[\/#{tag}\]\s*/mi, "\n\n[/#{tag}]\n\n")
    string.gsub!(/(?:\r?\n){3,}/, "\n\n")
    string.strip!

    string.split(/\n{2}/).each do |block|
      case block
      when "[#{tag}]"
        n += 1

      when "[/#{tag}]"
        n -= 1

      else
        if n == 0
          stripped << "#{block}\n\n"
        end
      end
    end

    stripped.strip
  end
end
