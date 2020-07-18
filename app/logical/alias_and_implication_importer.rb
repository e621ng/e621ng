class AliasAndImplicationImporter
  class Error < RuntimeError; end
  attr_accessor :bur, :text, :commands, :forum_id, :rename_aliased_pages, :creator_id, :creator_ip_addr

  def initialize(bur, text, forum_id, rename_aliased_pages = "0", creator = nil, ip_addr = nil)
    @bur = bur
    @forum_id = forum_id
    @text = text
    @rename_aliased_pages = rename_aliased_pages
    @creator_id = creator
    @creator_ip_addr = ip_addr
  end

  def process!(approver = CurrentUser.user)
    tokens = AliasAndImplicationImporter.tokenize(text)
    execute(tokens, approver)
  end

  def validate!
    tokens = AliasAndImplicationImporter.tokenize(text)
    validate_annotate(tokens)
  end

  def rename_aliased_pages?
    @rename_aliased_pages == "1"
  end

  def self.tokenize(text)
    text.split(/\r\n|\r|\n/).reject(&:blank?).map do |line|
      line = line.gsub(/[[:space:]]+/, " ").strip

      if line =~ /^(?:create alias|aliasing|alias) (\S+) -> (\S+)( #.*)?$/i
        [:create_alias, $1, $2, $3]

      elsif line =~ /^(?:create implication|implicating|implicate|imply) (\S+) -> (\S+)( #.*)?$/i
        [:create_implication, $1, $2, $3]

      elsif line =~ /^(?:remove alias|unaliasing|unalias) (\S+) -> (\S+)( #.*)?$/i
        [:remove_alias, $1, $2, $3]

      elsif line =~ /^(?:remove implication|unimplicating|unimplicate|unimply) (\S+) -> (\S+)( #.*)?$/i
        [:remove_implication, $1, $2, $3]

      elsif line =~ /^(?:mass update|updating|update|change) (.+?) -> (.*)( #.*)?$/i
        [:mass_update, $1, $2, $3]

      elsif line =~ /^category (\S+) -> (#{Tag.categories.regexp})( #.*)?$/i
        [:change_category, $1, $2, $3]

      elsif line.strip.empty?
        # do nothing

      else
        raise Error, "Unparseable line: #{line}"
      end
    end
  end

  def self.untokenize(tokens)
    tokens.map do |token|
      case token[0]
      when :create_alias
        comment = "# duplicate of #{token[3]}" if token[3].present?
        "alias #{token[1]} -> #{token[2]} #{comment}".strip
      when :create_implication
        comment = "# duplicate of #{token[3]}" if token[3].present?
        "implicate #{token[1]} -> #{token[2]} #{comment}".strip
      when :remove_alias
        comment = "# missing" if token[3] == false
        "unalias #{token[1]} -> #{token[2]} #{comment}".strip
      when :remove_implication
        comment = "# missing" if token[3] == false
        "unimplicate #{token[1]} -> #{token[2]} #{comment}".strip
      when :change_category
        "category #{token[1]} -> #{token[2]}".strip
      when :mass_update
        "update #{token[1]} -> #{token[2]}".strip
      else
        raise Error.new("Unknown token to reverse")
      end

    end
  end

  def validate_alias(token)
    tag_alias = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_alias.present? && tag_alias.has_transitives
      return [nil, "alias ##{tag_alias.id}, has blocking transitive relationships, cannot be applied through BUR"]
    end
    return [nil, "alias ##{tag_alias.id}"] unless tag_alias.nil?
    tag_alias = TagAlias.new(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
    unless tag_alias.valid?
      return ["Error: #{tag_alias.errors.full_messages.join("; ")} (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})", nil]
    end
    if tag_alias.has_transitives
      return [nil, "has blocking transitive relationships, cannot be applied through BUR"]
    end
    return [nil, nil]
  end

  def validate_implication(token)
    tag_implication = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    return [nil, "implication ##{tag_implication.id}"] unless tag_implication.nil?
    tag_implication = TagImplication.new(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
    unless tag_implication.valid?
      return ["Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})", nil]
    end
    return [nil, nil]
  end

  def validate_annotate(tokens)
    errors = []
    annotated = tokens.map do |token|
      case token[0]
      when :create_alias
        output = validate_alias(token)
        errors << output[0] if output[0].present?
        token[3] = output[1]
        token

      when :create_implication
        output = validate_implication(token)
        errors << output[0] if output[0].present?
        token[3] = output[1]
        token

      when :remove_alias
        existing = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2]).present?
        token[3] = existing
        token

      when :remove_implication
        existing = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2]).present?
        token[3] = existing
        token

      when :mass_update, :change_category
        token

      else
        errors << "Unknown token: #{token[0]}"
      end
    end
    [errors, AliasAndImplicationImporter.untokenize(annotated).join("\n")]
  end

  def estimate_update_count
    tokens = self.class.tokenize(text)
    tokens.inject(0) do |sum, token|
      case token[0]
      when :create_alias
        sum + TagAlias.new(antecedent_name: token[1], consequent_name: token[2]).estimate_update_count

      when :create_implication
        sum + TagImplication.new(antecedent_name: token[1], consequent_name: token[2]).estimate_update_count

      when :mass_update
        sum + ::Post.tag_match(token[1]).count

      when :change_category
        sum + Tag.find_by_name(token[1]).try(:post_count) || 0

      else
        sum + 0
      end
    end
  end

  def affected_tags
    tokens = self.class.tokenize(text)
    tokens.inject([]) do |all, token|
      case token[0]
      when :create_alias, :remove_alias, :create_implication, :remove_implication
        all << token[1]
        all << token[2]
        all

      when :mass_update
        all += Tag.scan_tags(token[1])
        all += Tag.scan_tags(token[2])
        all

      when :change_category
        all << token[1]
        all

      else
        all
      end
    end
  end

private

  ## These functions will find and appropriate existing aliases or implications if needed. This reduces friction with accepting
  # a BUR, and makes it much easier to work with.
  def find_create_alias(token, approver)
    tag_alias = TagAlias.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_alias.present?
      return unless tag_alias.status == 'pending'
      tag_alias.update_columns(creator_id: creator_id, creator_ip_addr: creator_ip_addr, forum_topic_id: forum_id)
    else
      tag_alias = TagAlias.create(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
      unless tag_alias.valid?
        raise Error, "Error: #{tag_alias.errors.full_messages.join("; ")} (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})"
      end
    end


    tag_alias.rename_artist if rename_aliased_pages?
    raise Error, "Error: Alias would modify other aliases or implications through transitive relationships. (create alias #{tag_alias.antecedent_name} -> #{tag_alias.consequent_name})" if tag_alias.has_transitives
    tag_alias.approve!(approver: approver, update_topic: false, deny_transitives: true)
  end

  def find_create_implication(token, approver)
    tag_implication = TagImplication.duplicate_relevant.find_by(antecedent_name: token[1], consequent_name: token[2])
    if tag_implication.present?
      return unless tag_implication.status == 'pending'
      tag_implication.update_columns(creator_id: creator_id, creator_ip_addr: creator_ip_addr, forum_topic_id: forum_id)
    else
      tag_implication = TagImplication.create(:forum_topic_id => forum_id, :status => "pending", :antecedent_name => token[1], :consequent_name => token[2])
      unless tag_implication.valid?
        raise Error, "Error: #{tag_implication.errors.full_messages.join("; ")} (create implication #{tag_implication.antecedent_name} -> #{tag_implication.consequent_name})"
      end
    end

    tag_implication.approve!(approver: approver, update_topic: false)
  end

  def execute(tokens, approver)
    warnings = []
    ActiveRecord::Base.transaction do
      tokens.map do |token|
        case token[0]
        when :create_alias
          find_create_alias(token, approver)

        when :create_implication
          find_create_implication(token, approver)

        when :remove_alias
          tag_alias = TagAlias.active.find_by(antecedent_name: token[1], consequent_name: token[2])
          raise Error, "Alias for #{token[1]} not found" if tag_alias.nil?
          tag_alias.reject!(update_topic: false)
          tag_alias.destroy

        when :remove_implication
          tag_implication = TagImplication.active.find_by(antecedent_name: token[1], consequent_name: token[2])
          raise Error, "Implication for #{token[1]} not found" if tag_implication.nil?
          tag_implication.reject!(update_topic: false)
          tag_implication.destroy

        when :mass_update
          TagBatchJob.perform_later(token[1], token[2], CurrentUser.id, CurrentUser.ip_addr)

        when :change_category
          tag = Tag.find_by_name(token[1])
          tag.category = Tag.categories.value_for(token[2])
          tag.save

        else
          raise Error, "Unknown token: #{token[0]}"
        end
      end
    end
  end
end
