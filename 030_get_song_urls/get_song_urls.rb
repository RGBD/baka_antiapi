require_relative '../common'

def main
  raise 'usage: binary songs_data_filename.jsonl cookie out_filename' unless ARGV.size == 3

  songs_data_filename = ARGV[0]
  cookie = ARGV[1]
  out_filename = ARGV[2]

  songs_data = File.readlines(songs_data_filename).map { |x| JSON.parse(x) }

  result = GetSongUrls.call(songs_data: songs_data, cookie: cookie)
  ap result
  require 'pry'; binding.pry

  File.write(out_filename, result.map { |x| JSON.dump(x) + "\n" }.join)
end

main if $PROGRAM_NAME == __FILE__
