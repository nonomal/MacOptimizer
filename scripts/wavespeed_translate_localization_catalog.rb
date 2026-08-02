#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
SOURCE_ROOT = File.join(ROOT, "AppUninstaller")
CATALOG_PATH = File.join(SOURCE_ROOT, "ConsolePhraseTranslations.swift")
CACHE_PATH = File.join(ROOT, ".wavespeed-localization-cache.json")
DEFAULT_KEY_PATH = File.expand_path("~/.codex/skills/wavespeed-image/secrets/wavespeed_api_key.txt")
ENDPOINT = URI("https://api.wavespeed.ai/api/v3/wavespeed-ai/any-llm")

LEGACY_PATTERN = /(?:loc|localization|LocalizationManager\.shared)\.text\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*\)/m
WRAPPER_PATTERN = /localized\(\s*"((?:\\.|[^"\\])*)"\s*,\s*"((?:\\.|[^"\\])*)"\s*\)/m
DICTIONARY_PATTERN = /"[^"\\]+"\s*:\s*\[\s*\.chinese\s*:\s*"((?:\\.|[^"\\])*)"\s*,\s*\.english\s*:\s*"((?:\\.|[^"\\])*)"\s*\]/m
# Restrict printf conversions to real specifiers. A broad `[a-zA-Z]` suffix
# misread ordinary UI copy such as "% total usage" as a placeholder (`% t`).
TOKEN_PATTERN = /\\\((?:[^()]|\([^()]*\))*\)|%(?:\d+\$)?[-+0 #]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[diuoxXfFeEgGaAcCsSp@]/

def swift_unescape(value)
  value.gsub('\\n', "\n").gsub('\\t', "\t").gsub('\\"', '"').gsub('\\\\', '\\')
end

def mask_tokens(value)
  tokens = []
  masked = value.gsub(TOKEN_PATTERN) do |token|
    marker = "__PH#{tokens.length}__"
    tokens << token
    marker
  end
  [swift_unescape(masked), tokens]
end

def restore_tokens(value, tokens)
  restored = value.to_s.strip
  tokens.each_with_index { |token, index| restored.gsub!("__PH#{index}__", token) }
  restored
end

def swift_literal(value)
  # Swift interpolation templates belong to the catalog as literal text.
  # Escaping every backslash makes `\(count)` compile as the characters
  # backslash-parenthesis instead of evaluating `count` in this static file.
  escaped = value.gsub('\\') { '\\\\' }.gsub('"', '\\"').gsub("\t", '\\t').gsub("\n", '\\n')
  %Q{"#{escaped}"}
end

def extract_json(text)
  stripped = text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
  JSON.parse(stripped)
end

def api_key
  from_env = ENV["WAVESPEED_API_KEY"].to_s.strip
  return from_env unless from_env.empty?
  path = ENV.fetch("WAVESPEED_API_KEY_FILE", DEFAULT_KEY_PATH)
  abort "WaveSpeed API key is missing" unless File.file?(path) && !File.zero?(path)
  File.read(path).strip
end

def translate_batch(entries, attempt: 1)
  source = entries.map do |entry|
    { id: entry.fetch(:id), simplifiedChinese: entry.fetch(:zh_masked), english: entry.fetch(:en_masked) }
  end
  prompt = <<~PROMPT
    Localize this JSON array of macOS application UI strings into Traditional Chinese, Japanese, Korean, and Russian.
    Return ONLY one valid JSON array. Each object must contain exactly: id, traditionalChinese, japanese, korean, russian.
    Use natural native macOS terminology and concise UI wording. Use both source fields to understand meaning.
    Preserve Mac, macOS, iOS, Finder, Safari, Xcode, CPU, DNS, USB, DMG, PID, Bundle ID, product names, file paths, and every placeholder like __PH0__ exactly.
    Do not mix languages, add notes, use Korean ambiguous particles such as 을(를)/이(가), or wrap the JSON in Markdown.
    Source JSON:
    #{JSON.generate(source)}
  PROMPT
  payload = {
    prompt: prompt,
    system_prompt: "You are a senior software localization translator. Output faithful, polished, single-language UI copy only. Never alter placeholders.",
    reasoning: false,
    priority: "latency",
    temperature: 0,
    max_tokens: 12_000,
    model: "google/gemini-2.5-flash",
    enable_sync_mode: true
  }
  request = Net::HTTP::Post.new(ENDPOINT)
  request["Authorization"] = "Bearer #{api_key}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(payload)
  response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 20, read_timeout: 180) do |http|
    http.request(request)
  end
  raise "WaveSpeed HTTP #{response.code}: #{response.body[0, 500]}" unless response.is_a?(Net::HTTPSuccess)
  envelope = JSON.parse(response.body)
  output = envelope.dig("data", "outputs", 0)
  raise "WaveSpeed task did not complete: #{envelope.dig('data', 'status')} #{envelope.dig('data', 'error')}" unless output
  translated = extract_json(output)
  by_id = translated.to_h { |item| [item.fetch("id"), item] }

  entries.each do |entry|
    item = by_id.fetch(entry.fetch(:id))
    %w[traditionalChinese japanese korean russian].each do |language|
      value = item.fetch(language).to_s.strip
      expected = entry.fetch(:tokens).each_index.map { |index| "__PH#{index}__" }.sort
      actual = value.scan(/__PH\d+__/).sort
      raise "placeholder mismatch for #{entry[:id]} #{language}" unless expected == actual
      raise "empty translation for #{entry[:id]} #{language}" if value.empty?
    end
  end
  by_id
rescue StandardError => error
  raise if attempt >= 3
  warn "Retrying batch after #{error.message}"
  translate_batch(entries, attempt: attempt + 1)
end

catalog = File.read(CATALOG_PATH)
# Normalize entries created by older versions of this script, which emitted
# executable Swift interpolations inside the static catalog.
catalog = catalog.each_line.map do |line|
  line.lstrip.start_with?(',"') ? line.gsub(/(?<!\\)\\\(/) { '\\\\(' } : line
end.join
# Keep the first curated entry when an older generator appended a duplicate.
seen_catalog_keys = {}
catalog = catalog.each_line.reject do |line|
  match = line.match(/^\s*,?"((?:\\.|[^"\\])*)"\s*:/)
  next false unless match
  key = swift_unescape(match[1])
  duplicate = seen_catalog_keys.key?(key)
  seen_catalog_keys[key] = true
  duplicate
end.join
File.write(CATALOG_PATH, catalog)

catalog_entries = {}
catalog.each_line do |line|
  next unless (match = line.match(/^\s*,?"((?:\\.|[^"\\])*)"\s*:\s*\[(.*)\]\s*$/))
  key = swift_unescape(match[1])
  values = {}
  match[2].scan(/\.(traditionalChinese|japanese|korean|russian)\s*:\s*"((?:\\.|[^"\\])*)"/) do |language, value|
    values[language] = swift_unescape(value)
  end
  catalog_entries[key] = values
end
required_languages = %w[traditionalChinese japanese korean russian]
catalog_keys = catalog_entries.select { |_key, values| required_languages.all? { |language| values.key?(language) } }.keys
pairs = {}
Dir.glob(File.join(SOURCE_ROOT, "**", "*.swift")).sort.each do |path|
  source = File.read(path)
  [LEGACY_PATTERN, WRAPPER_PATTERN, DICTIONARY_PATTERN].each do |pattern|
    source.scan(pattern) do |zh, en|
      zh = swift_unescape(zh)
      en = swift_unescape(en)
      next if catalog_keys.include?(en)
      pairs[en] ||= zh
    end
  end
end

cache = File.file?(CACHE_PATH) ? JSON.parse(File.read(CACHE_PATH)) : {}
pending = pairs.keys.reject { |english| cache.key?(english) }
pending.each_slice(12).with_index do |english_batch, batch_index|
  entries = english_batch.each_with_index.map do |english, index|
    en_masked, tokens = mask_tokens(english)
    zh_masked, zh_tokens = mask_tokens(pairs.fetch(english))
    raise "source placeholder count mismatch for #{english}" unless tokens.length == zh_tokens.length
    { id: "b#{batch_index}_#{index}", english: english, en_masked: en_masked, zh_masked: zh_masked, tokens: tokens }
  end
  translated = translate_batch(entries)
  entries.each do |entry|
    item = translated.fetch(entry.fetch(:id))
    cache[entry.fetch(:english)] = {
      "traditionalChinese" => restore_tokens(item.fetch("traditionalChinese"), entry.fetch(:tokens)),
      "japanese" => restore_tokens(item.fetch("japanese"), entry.fetch(:tokens)),
      "korean" => restore_tokens(item.fetch("korean"), entry.fetch(:tokens)),
      "russian" => restore_tokens(item.fetch("russian"), entry.fetch(:tokens))
    }
  end
  File.write(CACHE_PATH, JSON.pretty_generate(cache) + "\n")
  puts "Translated #{[batch_index * 12 + entries.length, pending.length].min}/#{pending.length} missing phrases"
end

entries = pairs.keys.sort.map do |english|
  generated = cache.fetch(english)
  values = generated.merge(catalog_entries.fetch(english, {}))
  %(        ,#{swift_literal(english)}: [.traditionalChinese: #{swift_literal(values.fetch('traditionalChinese'))}, .japanese: #{swift_literal(values.fetch('japanese'))}, .korean: #{swift_literal(values.fetch('korean'))}, .russian: #{swift_literal(values.fetch('russian'))}])
end
unless entries.empty?
  replacements = pairs.keys.to_h { |key| [key, entries[pairs.keys.sort.index(key)]] }
  replaced = {}
  updated_lines = catalog.each_line.map do |line|
    match = line.match(/^\s*,?"((?:\\.|[^"\\])*)"\s*:/)
    key = match && swift_unescape(match[1])
    if key && replacements.key?(key)
      replaced[key] = true
      replacements.fetch(key) + "\n"
    else
      line
    end
  end
  missing_lines = pairs.keys.reject { |key| replaced[key] }.sort.map { |key| replacements.fetch(key) }
  marker = "    ]\n}"
  updated = updated_lines.join
  abort "catalog closing marker not found" unless updated.include?(marker)
  updated = updated.sub(marker, "#{missing_lines.join("\n")}\n#{marker}") unless missing_lines.empty?
  File.write(CATALOG_PATH, updated)
end

# Canonicalize dictionary separators after replacing legacy trailing-comma
# entries with generated leading-comma entries. Swift accepts either style,
# but mixing them can leave a leading comma on the first element.
catalog = File.read(CATALOG_PATH)
seen_first_entry = false
catalog = catalog.each_line.map do |line|
  if line.match?(/^\s*,?"(?:\\.|[^"\\])*"\s*:\s*\[.*\],?\s*$/)
    content = line.strip.sub(/\A,/, "").sub(/,\z/, "")
    prefix = seen_first_entry ? "        ," : "        "
    seen_first_entry = true
    "#{prefix}#{content}\n"
  else
    line
  end
end.join
File.write(CATALOG_PATH, catalog)
puts "Added #{entries.length} complete six-language catalog entries."
