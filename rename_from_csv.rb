require 'csv'
require 'fileutils'
require 'awesome_print'

def main
  raise 'usage: binary csv_filename user_id_idx audio_id_idx artist_idx title_idx url_idx' unless ARGV.size == 6

  csv_filename = ARGV.shift
  user_id_idx, audio_id_idx, artist_idx, title_idx, url_idx = ARGV.map { |x| Integer(x) }

  file_utils = FileUtils::Verbose

  config = CSV.read(csv_filename).drop(1)

  file_utils.mkdir_p 'data_renamed'
  out_filenames = []

  config.each do |row|
    user_id, audio_id, artist, title = row.values_at(user_id_idx, audio_id_idx, artist_idx, title_idx)
    in_filename = "data/#{user_id}_#{audio_id}.mp3"
    out_filename = "data_renamed/#{artist} - #{title}.mp3"
    out_filenames << out_filename
    # file_utils.mv in_filename, out_filename
  end

  dups = out_filenames.each_with_object(Hash.new(0)) { |x, acc| acc[x] += 1 }.select { |k, v| v > 1 }

  unless dups.empty?
    puts 'dups:'
    ap dups
    raise 'dups not empty'
  end

  config.each do |row|
    user_id, audio_id, artist, title, url = row.values_at(user_id_idx, audio_id_idx, artist_idx, title_idx, url_idx)
    in_filename = "data/#{user_id}_#{audio_id}.mp3"
    next if url.to_s.empty?

    # raise "in_file #{in_filename} doesn't exist" unless File.exist?(in_filename)
    next unless File.exist?(in_filename)

    out_filename = "data_renamed/#{artist} - #{title}.mp3"
    # out_filenames << out_filename
    raise "file #{out_filename} already exists (target for #{in_filename})" if File.exist?(out_filename)

    file_utils.mv in_filename, out_filename
  end

  require 'pry'; binding.pry
end

main if $PROGRAM_NAME == __FILE__
