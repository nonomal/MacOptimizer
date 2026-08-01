#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "openssl"
require "thread"
require "uri"

ROOT = File.expand_path("..", __dir__)
SOURCE_ROOT = File.join(ROOT, "AppUninstaller")
CACHE_PATH = File.join(ROOT, ".strict-localization-cache.json")

CALL_PATTERN = /(?<receiver>(?:loc|localization|LocalizationManager\.shared))\.text\(\s*(?<zh>"(?:\\.|[^"\\])*")\s*,\s*(?<en>"(?:\\.|[^"\\])*")\s*\)/m
TARGETS = {
  traditionalChinese: ["zh-CN", "zh-TW", :zh],
  japanese: ["en", "ja", :en],
  korean: ["en", "ko", :en],
  russian: ["en", "ru", :en]
}.freeze

Pair = Struct.new(:zh_raw, :en_raw, :translations, keyword_init: true)

def literal_body(literal)
  literal[1...-1]
end

def mask_swift_tokens(raw)
  tokens = []
  masked = +""
  index = 0

  while index < raw.length
    if raw[index, 2] == "\\("
      start = index
      index += 2
      depth = 1
      in_string = false
      escaped = false
      while index < raw.length && depth.positive?
        char = raw[index]
        if in_string
          if escaped
            escaped = false
          elsif char == "\\"
            escaped = true
          elsif char == '"'
            in_string = false
          end
        else
          case char
          when '"' then in_string = true
          when '(' then depth += 1
          when ')' then depth -= 1
          end
        end
        index += 1
      end
      token = raw[start...index]
      marker = "<x#{tokens.length}/>"
      tokens << token
      masked << marker
    elsif (match = raw[index..].match(/\A%(?:\d+\$)?[-+0 #]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[a-zA-Z@]/))
      token = match[0]
      marker = "<x#{tokens.length}/>"
      tokens << token
      masked << marker
      index += token.length
    else
      masked << raw[index]
      index += 1
    end
  end

  plain = masked
    .gsub('\\n', "\n")
    .gsub('\\t', "\t")
    .gsub('\\"', '"')
    .gsub('\\\\', '\\')

  [plain, tokens]
end

def restore_swift_literal(translated, tokens)
  value = CGI.unescapeHTML(translated.to_s).strip
  tokens.each_with_index do |token, index|
    value.gsub!(/<\s*x\s*#{index}\s*\/\s*>/i, token)
  end

  unresolved = value.scan(/<\s*x\s*\d+\s*\/\s*>/i)
  raise "unresolved placeholders: #{unresolved.join(', ')} in #{value.inspect}" unless unresolved.empty?

  protected_tokens = []
  value.gsub!(/\\\((?:[^()]|\([^()]*\))*\)|%(?:\d+\$)?[-+0 #]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[a-zA-Z@]/) do |token|
    marker = "\u{E000}#{protected_tokens.length}\u{E001}"
    protected_tokens << token
    marker
  end

  value = value
    .gsub('\\', '\\\\')
    .gsub('"', '\\"')
    .gsub("\t", '\\t')
    .gsub("\n", '\\n')

  protected_tokens.each_with_index do |token, index|
    value.gsub!("\u{E000}#{index}\u{E001}", token)
  end
  "\"#{value}\""
end

def translate(text, source, target)
  uri = URI("https://api.mymemory.translated.net/get")
  uri.query = URI.encode_www_form(q: text, langpair: "#{source}|#{target}")
  response = Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: true,
    open_timeout: 10,
    read_timeout: 25
  ) { |http| http.get(uri.request_uri) }

  raise "translation HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  payload = JSON.parse(response.body)
  raise "translation quota exhausted: #{payload['responseDetails']}" if payload["quotaFinished"]
  raise "translation failed: #{payload['responseDetails']}" unless payload.dig("responseData", "translatedText")
  payload.dig("responseData", "translatedText")
end

files = Dir.glob(File.join(SOURCE_ROOT, "**", "*.swift")).sort
pairs = {}
files.each do |path|
  File.read(path).scan(CALL_PATTERN) do
    match = Regexp.last_match
    key = [match[:zh], match[:en]]
    pairs[key] ||= Pair.new(zh_raw: match[:zh], en_raw: match[:en], translations: {})
  end
end

cache = File.exist?(CACHE_PATH) ? JSON.parse(File.read(CACHE_PATH)) : {}
jobs = Queue.new
pending = Hash.new { |hash, key| hash[key] = [] }
cached_only = ARGV.include?("--cached-only")

pairs.each_value do |pair|
  TARGETS.each do |language, (source, target, source_side)|
    source_raw = source_side == :zh ? pair.zh_raw : pair.en_raw
    plain, tokens = mask_swift_tokens(literal_body(source_raw))
    cache_key = [source, target, plain].join("\u0000")
    if cache[cache_key]
      pair.translations[language] = restore_swift_literal(cache[cache_key], tokens)
    else
      pending[[source, target]] << {
        pair: pair,
        language: language,
        plain: plain,
        tokens: tokens,
        cache_key: cache_key
      }
    end
  end
end

pending.each do |(source, target), entries|
  next if cached_only
  batch = []
  batch_bytes = 0
  entries.each do |entry|
    estimated_bytes = entry[:plain].bytesize + 18
    if !batch.empty? && batch_bytes + estimated_bytes > 430
      jobs << [source, target, batch]
      batch = []
      batch_bytes = 0
    end
    batch << entry
    batch_bytes += estimated_bytes
  end
  jobs << [source, target, batch] unless batch.empty?
end

mutex = Mutex.new
errors = Queue.new
workers = Array.new([6, jobs.size].min) do
  Thread.new do
    until jobs.empty?
      begin
        source, target, batch = jobs.pop(true)
      rescue ThreadError
        break
      end

      begin
        joined = batch.each_with_index.map { |entry, index| "#{entry[:plain]} <s#{index}/>" }.join(" ")
        translated_batch = translate(joined, source, target)
        translated_items = translated_batch.split(/\s*<\s*s\s*\d+\s*\/\s*>\s*/i)
        raise "batch separator mismatch" unless translated_items.length == batch.length

        mutex.synchronize do
          batch.zip(translated_items).each do |entry, translated|
            cache[entry[:cache_key]] = translated
            entry[:pair].translations[entry[:language]] = restore_swift_literal(translated, entry[:tokens])
          end
          File.write(CACHE_PATH, JSON.pretty_generate(cache) + "\n")
        end
      rescue StandardError => error
        # A provider occasionally drops a separator. Retry only that batch
        # one phrase at a time so no phrase can be assigned to its neighbour.
        batch.each do |entry|
          begin
            translated = translate(entry[:plain], source, target)
            literal = restore_swift_literal(translated, entry[:tokens])
            mutex.synchronize do
              cache[entry[:cache_key]] = translated
              entry[:pair].translations[entry[:language]] = literal
              File.write(CACHE_PATH, JSON.pretty_generate(cache) + "\n")
            end
          rescue StandardError => individual_error
            errors << "#{source}->#{target} #{entry[:plain].inspect}: #{error.message}; retry: #{individual_error.message}"
          end
        end
      end
    end
  end
end
workers.each(&:join)

unless errors.empty?
  warn errors.pop until errors.empty?
  abort "Strict localization generation failed"
end

files.each do |path|
  source = File.read(path)
  rewritten = source.gsub(CALL_PATTERN) do
    match = Regexp.last_match
    pair = pairs.fetch([match[:zh], match[:en]])
    next match[0] unless TARGETS.keys.all? { |language| pair.translations[language] }
    <<~SWIFT.chomp
      #{match[:receiver]}.text(
          simplifiedChinese: #{pair.zh_raw},
          traditionalChinese: #{pair.translations.fetch(:traditionalChinese)},
          english: #{pair.en_raw},
          japanese: #{pair.translations.fetch(:japanese)},
          korean: #{pair.translations.fetch(:korean)},
          russian: #{pair.translations.fetch(:russian)}
      )
    SWIFT
  end
  File.write(path, rewritten) if rewritten != source
end

complete_count = pairs.values.count { |pair| TARGETS.keys.all? { |language| pair.translations[language] } }
puts "Localized #{complete_count}/#{pairs.length} distinct Chinese/English phrase pairs in #{files.length} Swift files."
