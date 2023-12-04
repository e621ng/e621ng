# Diffy normally calls out to git diff, this makes it use libgit2 instead
module DiffyNoSubprocess
  # https://github.com/samg/diffy/blob/85b18fa6b659f724937dea58ebbc0564f4475c8c/lib/diffy/diff.rb#L43-L77
  def diff
    @diff ||= Rugged::Patch.from_strings(@string1, @string2, context_lines: 10_000).to_s.force_encoding("UTF-8")
  end

  # https://github.com/samg/diffy/blob/85b18fa6b659f724937dea58ebbc0564f4475c8c/lib/diffy/diff.rb#L79-L100
  def each(&)
    # The first 5 lines are git diff header lines
    diff.lines.drop(5).each(&)
  end
end
