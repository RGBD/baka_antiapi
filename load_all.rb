require_relative './common'

module FileWriteThroughTmp
  def self.call(filename, content)
    tmp_filename = File.dirname(filename) + "/." + File.basename(filename) + '.tmp'
    File.write(tmp_filename, content)
    FileUtils.mv(tmp_filename, filename)
  end
end

def main
  raise 'usage: binary url cookie out_filename' unless ARGV.size == 3

  url = ARGV[0]
  cookie = ARGV[1]
  out_filename = ARGV[2]

  result = []

  now = Time.now.utc
  File.open("load_all_song_datas_#{now.iso8601}.jsonl", 'w') do |f|
    LoadAllSongsData.call(url: url, cookie: cookie).each_slice(5) do |slice|
      song_urls_slice = slice.select do |row|
        files = Dir["data/#{row[1]}_#{row[0]}.*"]
        if files.empty?
          true
        else
          puts "SKIPPING GET URL, already downloaded: #{row[1]}_#{row[0]}"
          row[2] = 'downloaded'
          false
        end
      end
      song_urls = GetSongUrls.call(songs_data: song_urls_slice, cookie: cookie)
      song_urls.each { |x| x[2] = UnmaskUrl.call(url: x[2]) }

      song_urls.each do |song_url_row|
        slice_element = slice.find { |x| x[0] == song_url_row[0] && x[1] == song_url_row[1] }
        slice_element[2] = song_url_row[2]
      end

      # ap slice.map { |x| x.first(5) }

      slice.each do |row|
        ap row.first(5)

        f << JSON.dump(row) << "\n"
        f.flush

        next if row[2].to_s.empty? || row[2].to_s == 'downloaded'

        # require 'pry'; binding.pry
        ext =
          if row[2].include?('.m3u8')
            'ts'
          elsif row[2].include?('.mp3')
            'mp3'
          else
            require 'pry'; binding.pry
          end
        filename = "data/#{row[1]}_#{row[0]}.#{ext}"
        next if File.exist?(filename)

        song_bits = DownloadMusicFile.call(url: row[2])
        if song_bits.bytesize < 100_000
          require 'pry'; binding.pry
        end
        FileUtils.mkdir_p(File.dirname(filename))
        FileWriteThroughTmp.call(filename, song_bits)
      end

      result.concat(slice)
    end
  end

  File.write(out_filename, result.map { |x| JSON.dump(x) + "\n" }.join)
end

main if $PROGRAM_NAME == __FILE__
