require_relative '../common'

def main
  raise 'usage: binary url cookie out_filename' unless ARGV.size == 3

  url = ARGV[0]
  cookie = ARGV[1]
  out_filename = ARGV[2]

  result = LoadAudiosPage.call(url: url, cookie: cookie)

  ap result

  File.write(out_filename, JSON.pretty_generate(result))
end

main if $PROGRAM_NAME == __FILE__
