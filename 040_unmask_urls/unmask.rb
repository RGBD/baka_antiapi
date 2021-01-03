require '../common.rb'

def main
  raise 'usage: binary url' unless ARGV.size == 1

  url = ARGV[0]

  result = UnmaskUrl.call(url: url)

  puts result
end

main if $PROGRAM_NAME == __FILE__
