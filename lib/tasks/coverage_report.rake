# frozen_string_literal: true

namespace :coverage do # rubocop:disable Metrics/BlockLength
  desc "Show which models have spec files vs. only incidental coverage"
  task models: :environment do # rubocop:disable Metrics/BlockLength
    require "json"

    coverage_file = Rails.root.join("coverage/coverage.json")
    coverage_data = File.exist?(coverage_file) ? JSON.parse(File.read(coverage_file))["coverage"] : {}

    # Normalize coverage keys: strip leading /app prefix if running in Docker
    coverage_by_relative = coverage_data.transform_keys do |k|
      k.sub(%r{\A/app/}, "")
    end

    model_files = Dir[Rails.root.join("app/models/*.rb").to_s]
    rows = model_files.map do |model_path|
      relative = Pathname.new(model_path).relative_path_from(Rails.root).to_s
      model_name = File.basename(model_path, ".rb")

      has_spec = Dir[Rails.root.join("spec/models/#{model_name}/**/*_spec.rb").to_s].any? ||
                 Rails.root.join("spec/models/#{model_name}_spec.rb").exist?

      lines = coverage_by_relative.dig(relative, "lines") || []
      executable = lines.count { |l| !l.nil? }
      covered    = lines.count { |l| l.is_a?(Integer) && l > 0 }
      pct = executable > 0 ? (covered.to_f / executable * 100).round(1) : nil

      { name: model_name, has_spec: has_spec, pct: pct, executable: executable, covered: covered }
    end

    no_spec  = rows.reject { |r| r[:has_spec] }.sort_by { |r| -(r[:pct] || 0) }
    has_spec = rows.select { |r| r[:has_spec] }.sort_by { |r| -(r[:pct] || 0) }

    fmt = "  %-40s  %8s  %s"
    header = format(fmt, "Model", "Coverage", "Lines (covered/total)")

    puts "\n=== Models WITH spec files (#{has_spec.size}) ==="
    puts header
    has_spec.each do |r|
      cov = r[:pct] ? "#{r[:pct]}%" : "n/a"
      puts format(fmt, r[:name], cov, "#{r[:covered]}/#{r[:executable]}")
    end

    puts "\n=== Models WITHOUT spec files (#{no_spec.size}) ==="
    puts header
    no_spec.each do |r|
      cov = r[:pct] ? "#{r[:pct]}%" : "n/a"
      puts format(fmt, r[:name], cov, "#{r[:covered]}/#{r[:executable]}")
    end

    puts "\nSummary: #{has_spec.size}/#{rows.size} models have explicit spec files"
  end
end
