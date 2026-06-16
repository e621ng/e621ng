# frozen_string_literal: true

# Benchmarks the raw SQL behind each DbExportJob export by running it through
# EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON). This measures the query itself
# (not the COPY/gzip/storage wrapper) and reports how many times Postgres
# actually executes each subquery/lateral join in the plan - a LATERAL join
# or correlated subquery shows up as a single statement in the SQL, but the
# executor runs it once per outer row, which EXPLAIN ANALYZE exposes via
# "Actual Loops" on the inner side of the plan.
#
# Usage: bin/benchmark_export_queries [export_name ...]
# With no arguments, all export types are benchmarked.

require "json"

requested = ARGV.dup
exports = requested.empty? ? DbExportJob::EXPORTS : DbExportJob::EXPORTS.slice(*requested)

unknown = requested - DbExportJob::EXPORTS.keys
if unknown.any?
  puts "Unknown export type(s): #{unknown.join(', ')}"
  puts "Available: #{DbExportJob::EXPORTS.keys.join(', ')}"
  exit 1
end

# Nodes whose "Parent Relationship" marks them as something the executor
# re-runs per outer row/value, rather than once for the whole query.
PER_ROW_RELATIONSHIPS = %w[Inner Subquery SubPlan InitPlan].freeze

def walk_plan(node, &block)
  block.call(node)
  (node["Plans"] || []).each { |child| walk_plan(child, &block) }
end

def analyze(sql)
  conn = ActiveRecord::Base.connection
  conn.execute("SET statement_timeout = 0")

  raw = conn.select_value("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{sql}")
  plan_set = raw.is_a?(String) ? JSON.parse(raw) : raw
  root = plan_set.first

  all_nodes = []
  per_row_nodes = []
  walk_plan(root["Plan"]) do |node|
    all_nodes << node
    per_row_nodes << node if PER_ROW_RELATIONSHIPS.include?(node["Parent Relationship"])
  end

  {
    planning_ms: root["Planning Time"],
    execution_ms: root["Execution Time"],
    total_nodes: all_nodes.size,
    per_row_nodes: per_row_nodes.pluck("Node Type"),
    per_row_invocations: per_row_nodes.sum { |n| n["Actual Loops"] || 1 },
  }
ensure
  conn&.execute("RESET statement_timeout")
end

results = []

exports.each do |name, config|
  puts "* Benchmarking #{name} query"

  stats = analyze(config[:query].call)
  # 1 main query + every time a per-row subquery/lateral node actually ran
  total_queries = 1 + stats[:per_row_invocations]

  results << stats.merge(name: name, total_queries: total_queries)

  puts format(
    "  %<name>-22s planning %<planning>8.2fms | execution %<execution>10.2fms | %<nodes>d plan nodes | %<subq>d subquery executions (%<types>s)",
    name: name, planning: stats[:planning_ms], execution: stats[:execution_ms], nodes: stats[:total_nodes],
    subq: stats[:per_row_invocations], types: stats[:per_row_nodes].tally
  )
end

puts "\n#{'Export'.ljust(22)} #{'Planning'.rjust(10)} #{'Execution'.rjust(12)} #{'Nodes'.rjust(7)} #{'Subq Runs'.rjust(10)} #{'Total Qs'.rjust(10)}"
results.each do |r|
  puts format(
    "%<name>-22s %<planning>9.2fms %<execution>11.2fms %<nodes>7d %<subq>10d %<total>10d",
    name: r[:name], planning: r[:planning_ms], execution: r[:execution_ms], nodes: r[:total_nodes],
    subq: r[:per_row_invocations], total: r[:total_queries]
  )
end
