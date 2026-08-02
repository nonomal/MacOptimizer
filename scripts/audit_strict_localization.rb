#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)
SOURCE_ROOT = File.join(ROOT, "AppUninstaller")
files = Dir.glob(File.join(SOURCE_ROOT, "**", "*.swift")).sort

def swift_unescape(value)
  value.gsub('\\n', "\n").gsub('\\t', "\t").gsub('\\"', '"').gsub('\\\\', '\\')
end

catalog_source = File.read(File.join(SOURCE_ROOT, "ConsolePhraseTranslations.swift"))
required_languages = %w[traditionalChinese japanese korean russian]
catalog_keys = catalog_source.each_line.each_with_object([]) do |line, keys|
  match = line.match(/^\s*,?"((?:\\.|[^"\\])*)"\s*:\s*\[(.*)\]\s*$/)
  next unless match
  present = match[2].scan(/\.(traditionalChinese|japanese|korean|russian)\s*:/).flatten.uniq
  keys << swift_unescape(match[1]) if required_languages.all? { |language| present.include?(language) }
end.uniq

legacy_pattern = /(?:loc|localization|LocalizationManager\.shared)\.text\(\s*"(?:\\.|[^"\\])*"\s*,\s*"((?:\\.|[^"\\])*)"\s*\)/m
wrapper_pattern = /localized\(\s*"(?:\\.|[^"\\])*"\s*,\s*"((?:\\.|[^"\\])*)"\s*\)/m
dictionary_pattern = /"[^"\\]+"\s*:\s*\[\s*\.chinese\s*:\s*"(?:\\.|[^"\\])*"\s*,\s*\.english\s*:\s*"((?:\\.|[^"\\])*)"\s*\]/m

missing_catalog = []
language_branches = []
files.each do |path|
  source = File.read(path)
  relative = path.delete_prefix("#{ROOT}/")

  source.to_enum(:scan, /currentLanguage\s*==\s*\.chinese/).each do
    line = source[0...Regexp.last_match.begin(0)].count("\n") + 1
    language_branches << "#{relative}:#{line}"
  end

  [legacy_pattern, wrapper_pattern, dictionary_pattern].each do |pattern|
    source.to_enum(:scan, pattern).each do
      english = swift_unescape(Regexp.last_match[1])
      next if catalog_keys.include?(english)
      line = source[0...Regexp.last_match.begin(0)].count("\n") + 1
      missing_catalog << "#{relative}:#{line}: #{english}"
    end
  end
end

puts "Strict localization audit"
puts "  legacy Chinese-only branches: #{language_branches.length}"
puts "  two-language phrases/dictionary values without a complete catalog entry: #{missing_catalog.length}"

unless language_branches.empty?
  puts "\nChinese-only branches:"
  puts language_branches
end

unless missing_catalog.empty?
  puts "\nMissing six-language phrases:"
  puts missing_catalog
end

exit(language_branches.empty? && missing_catalog.empty? ? 0 : 1)
