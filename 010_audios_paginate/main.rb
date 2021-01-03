require_relative '../common'

def main
  raise 'usage: binary section_id start_from cookie out_filename' unless ARGV.size == 4

  section_id = ARGV[0]
  start_from = ARGV[1]
  cookie = ARGV[2]
  out_filename = ARGV[3]

  result = LoadNextAudioPage.call(section_id: section_id, start_from: start_from, cookie: cookie)

  require 'pry'; binding.pry

  ap result

  File.write(out_filename, JSON.pretty_generate(result))
end

main if $PROGRAM_NAME == __FILE__

