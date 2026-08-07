# frozen_string_literal: true

require "cgi"
require "strscan"

# Turns a rendered DText body into a linkable outline. #html returns the body with an id
# on every header and section summary, and #entries returns the matching outline, so each
# entry's slug addresses an element in #html.
class WikiTableOfContents
  NAV_GLYPHS = /[\^↑⬆▲⇧]/
  BACK_TO_TOP = %r{<a\b[^>]*href="#top"[^>]*>.*?</a>}m
  ANCHOR_ID = /<a\b[^>]*\sid="([^"]*)"/
  CLOSINGS = ["</summary>", *(1..6).map { |n| "</h#{n}>" }].index_with { |tag| /#{Regexp.escape(tag)}/m }.freeze

  Node = Struct.new(:kind, :level, :text, :slug, :children, keyword_init: true)

  def initialize(html)
    @html = html.to_s
    @out = +""
    @used = Set.new
    # Reserve pre-existing ids first so a generated slug also avoids ones appearing later.
    @html.scan(/\sid="([^"]*)"/) { |(id)| reserve(id) }
    @root = Node.new(kind: :root, level: 0, text: nil, slug: nil, children: [])
    scan
    merge(@root)
  end

  def html
    @out.html_safe # rubocop:disable Rails/OutputSafety -- Already safe DText html
  end

  def entries
    @entries ||= [].tap { |list| flatten(@root, -1, list) }
  end

  private

  def scan
    scanner = StringScanner.new(@html)
    stack = [{ frame: :root, level: 0, node: @root }]

    until scanner.eos?
      if scanner.scan(/(<details\b[^>]*>)(\s*)<summary\b([^>]*)>/m)
        push_section(stack, scanner[1], scanner[2], scanner[3], read_until(scanner, "</summary>"))
      elsif scanner.scan(%r{</details>})
        @out << "</details>"
        close_section(stack)
      elsif scanner.scan(/<h([1-6])((?:\s[^>]*)?)>/)
        level = scanner[1].to_i
        push_header(stack, level, scanner[2], read_until(scanner, "</h#{level}>"))
      else
        @out << (scanner.scan(/[^<]+/) || scanner.getch).to_s
      end
    end
  end

  def read_until(scanner, closing)
    # An unclosed tag consumes the rest of the document.
    chunk = scanner.scan_until(CLOSINGS.fetch(closing)) || scanner.rest.tap { scanner.terminate }
    chunk.delete_suffix(closing)
  end

  def push_section(stack, open_details, spacing, summary_attrs, inner)
    label = clean_label(inner)
    existing = existing_id(inner, summary_attrs)
    parent = stack.last

    if existing
      reserve(existing)
      slug = existing
      inject = false
    elsif (base = slugify(label)).blank?
      slug = base
      inject = false
    elsif merge_partner?(parent, base)
      slug = parent[:node].slug
      inject = false
    else
      slug = unique_slug(base)
      inject = true
    end

    summary = inject ? %(<summary#{summary_attrs} id="#{slug}">) : "<summary#{summary_attrs}>"
    @out << open_details << spacing << summary << inner << "</summary>"

    node = Node.new(kind: :section, level: nil, text: label.presence, slug: slug, children: [])
    parent[:node].children << node
    stack.push({ frame: :section, level: nil, node: node })
  end

  def close_section(stack)
    stack.pop while stack.size > 1 && stack.last[:frame] != :section
    stack.pop if stack.size > 1
  end

  def push_header(stack, level, attrs, inner)
    label = clean_label(inner)
    existing = existing_id(inner, attrs)

    if existing
      reserve(existing)
      slug = existing
      @out << "<h#{level}#{attrs}>" << inner << "</h#{level}>"
    elsif (slug = slugify(label)).present?
      slug = unique_slug(slug)
      @out << %(<h#{level}#{attrs} id="#{slug}">) << inner << "</h#{level}>"
    else
      @out << "<h#{level}#{attrs}>" << inner << "</h#{level}>"
    end

    return if slug.blank?

    stack.pop while stack.last[:frame] == :header && stack.last[:level] >= level
    node = Node.new(kind: :header, level: level, text: label.presence, slug: slug, children: [])
    stack.last[:node].children << node
    stack.push({ frame: :header, level: level, node: node })
  end

  def existing_id(inner, attrs)
    (inner[ANCHOR_ID, 1] || attrs[/\sid="([^"]*)"/, 1]).presence
  end

  # A header directly followed by a same-slug section is one anchor, so they share the id and fold in #merge.
  def merge_partner?(parent, base)
    parent[:frame] == :header && parent[:node].children.empty? && parent[:node].slug == base
  end

  def unique_slug(base)
    candidate = base
    suffix = 0
    while @used.include?(candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    @used << candidate
    candidate
  end

  def reserve(id)
    @used << id if id.present?
  end

  def merge(node)
    node.children.each { |child| merge(child) }
    first = node.children.first
    return unless node.kind == :header && first&.kind == :section && first.slug == node.slug

    node.children = first.children + node.children[1..]
  end

  def flatten(node, depth, list)
    list << { depth: depth, slug: node.slug, text: node.text } if node.text
    node.children.each { |child| flatten(child, depth + 1, list) }
  end

  def clean_label(inner)
    text = CGI.unescapeHTML(inner.gsub(BACK_TO_TOP, "").gsub(/<[^>]+>/, ""))
    text.gsub(/\A(?:\s|#{NAV_GLYPHS})+|(?:\s|#{NAV_GLYPHS})+\z/, "").sub(/:\s*\z/, "")
  end

  # A parenthetical is a disambiguating qualifier, so slug on the bare name unless that empties it.
  def slugify(text)
    normalized = text.to_s.downcase
    to_slug(normalized.gsub(/\s*\([^()]*\)/, "")).presence || to_slug(normalized)
  end

  def to_slug(text)
    text.gsub(/[^\p{Alnum}]+/, "-").delete_prefix("-").delete_suffix("-")
  end
end
