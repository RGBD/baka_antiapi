require 'json'
require 'csv'
require 'cgi'
require 'awesome_print'

require_relative './artist_whitelist'
require_relative './song_capitalise'

def canonize(string)
  string = string.gsub(/[^\p{L}[:digit:]'",&.()!?\[\] -]/, '').gsub(/\s/, ' ').gsub(/ +/, ' ').downcase.strip
  song_capitalise(string)
end

def normalize(string)
  string.gsub(/[^\p{L}[:digit:] ]/, '').gsub(/ +/, ' ').downcase
end

def get_artist(string)
  string_orig = string
  string = normalize(string)
  match = ARTIST_WHITELIST.map do |row|
    if row.is_a?(String)
      normalize(row) == string && row || nil
    elsif row.is_a?(Array)
      row.map do |variant|
        normalize(variant) == string && row.first || nil
      end.compact.first
    end
  end.compact.first

  match
end

found_count = 0
total_count = 0
artists = []
data = File.readlines('song_data_full_list_2021-01-02.jsonl').map { |x| JSON.parse(x) }
data.each do |row|
  row[3] = CGI.unescapeHTML(row[3].to_s.strip).gsub("\uFEFF", '')
  row[4] = CGI.unescapeHTML(row[4].to_s.strip).gsub("\uFEFF", '')
end

dups = data.map { |x| [canonize(x[3]), get_artist(x[4]) || canonize(x[4])].join(' - ') }.each_with_object(Hash.new(0)) { |x, acc| acc[x] += 1 }.select { |k, v| v > 1 }

puts 'dups counted'

csv_data = CSV.generate(force_quotes: true) do |csv|
  csv << %w[best_artist best_title artist title is_dup audio_id user_id downloaded]
  data.each do |row|
    total_count += 1
    row = row.first(5)

    artist = row[4]
    title = row[3]

    found_artist = get_artist(row[4])
    artists << row[4] unless found_artist
    found_count += 1 if found_artist

    best_title = canonize(title)
    best_artist = found_artist || canonize(artist)

    is_dup = dups.key?([best_title, best_artist].join(' - ')) ? 'DUP' : nil

    row = [
      best_artist,
      best_title,
      artist,
      title,
      is_dup,
      row[0],
      row[1],
      row[2],
    ]
    # row[5] = row[3]
    # row[6] = row[4]
    # require 'pry'; binding.pry if is_dup
    csv << row.map { |x| x.is_a?(String) || x.is_a?(Numeric) || x.is_a?(NilClass) ? x : JSON.dump(x) }
  end
end
File.write(
  'song_data_2021-01-02.csv',
  csv_data
)
ap [found_count, total_count]
require 'pry'; binding.pry

puts 'exit'
