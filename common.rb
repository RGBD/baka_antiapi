require 'awesome_print'
require 'json'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'rack/utils'
require 'time'
require 'uri'

module LoadGeneric
  def self.call(url:, cookie:)
    uri = URI(url)

    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'Mozilla Linux Firefox'
    req['Cookie'] = cookie

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http|
      http.request(req)
    }

    unless res.is_a? Net::HTTPOK
      puts res.class
      raise 'not OK'
    end

    res.body
  end
end

module LoadAudiosPage
  def self.call(url: , cookie:)
    filename = 'ruby_result.html'
    if true
      result = LoadGeneric.call(url: url, cookie: cookie)
      File.write(filename, result)
    else
      result = File.read(filename)
    end

    page = Nokogiri::HTML(result.dup.force_encoding('BINARY'))
    cur_audio_page_line = page.css('body>script').find { |x| x.inner_text.include?('cur.audioPage') }.inner_text.split("\n").map(&:chomp).find { |x| x.include?('cur.audioPage') }

    audio_config = cur_audio_page_line.gsub(/^.*page_layout'\)\), /, '').gsub(/\);  ;.*$/, '')
    audio_config = JSON.parse(audio_config)

    section_id = audio_config['sectionData']['all']['sectionId']
    next_from = audio_config['sectionData']['all']['nextFrom']

    raise 'no next from unless next_from' unless next_from

    songs_elements = page.css('.CatalogBlock__content .audio_page__audio_rows_list ._audio_row')
    songs_data_from_page = songs_elements.map { |x| JSON.parse(x.attr('data-audio')) }

    songs_data_from_config = audio_config['sectionData']['all']['playlist']['list']

    {
      songs_data: songs_data_from_config,
      section_id: section_id,
      next_from: next_from,
    }
  end
end

module LoadWithPost
  def self.call(url:, headers:, data:)
    uri = URI(url)

    req = Net::HTTP::Post.new(uri)
    req.set_form_data(data)

    headers.each do |k, v|
      req[k] = v
    end

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http|
      http.request(req)
    }

    raise 'not OK' unless res.is_a? Net::HTTPOK

    res.body

  end
end

module LoadNextAudioPageRaw
  def self.call(section_id:, start_from:, cookie:)
    url = 'https://vk.com/al_audio.php'

    headers = {
      'User-Agent' => 'Mozilla Linux Firefox',
      'Cookie' => cookie,
      'X-Requested-With' => 'XMLHttpRequest',
    }

    data = {
      'act' => 'load_catalog_section',
      'al' => '1',
      'section_id' => section_id,
      'start_from' => start_from,
    }

    result = LoadWithPost.call(url: url, headers: headers, data: data)

    result
  end
end

module LoadNextAudioPage
  def self.call(section_id:, start_from:, cookie:)
    url = 'https://vk.com/al_audio.php'

    result = LoadNextAudioPageRaw.call(section_id: section_id, start_from: start_from, cookie: cookie)

    result = JSON.parse(result.dup.force_encoding('CP1251').encode('utf-8'))

    songs_data = result['payload'][1][1]['playlist']['list']
    section_id = result['payload'][1][1]['playlist']['id']
    next_from = result['payload'][1][1]['nextFrom']

    {
      songs_data: songs_data,
      section_id: section_id,
      next_from: next_from,
    }
  end
end

module LoadAllSongsData
  def self.call(url:, cookie:)
    return enum_for(__method__, url: url, cookie: cookie) unless block_given?

    songs_data_count = 0

    section_id = nil
    next_from = nil
    first_time = true

    loop do
      if first_time
        first_time = false
        curr_page_data = LoadAudiosPage.call(url: url, cookie: cookie)
      else
        delay = 10
        puts "sleep #{delay} start"
        sleep delay
        puts "sleep #{delay} finish"
        curr_page_data = LoadNextAudioPage.call(section_id: section_id, start_from: next_from, cookie: cookie)
      end

      section_id = curr_page_data[:section_id]
      next_from = curr_page_data[:next_from]

      puts "page loaded, data size: #{songs_data_count} (+#{curr_page_data[:songs_data].size})"

      ap({
        songs_data_size: curr_page_data[:songs_data].size,
        section_id: section_id,
        next_from: next_from,
      })

      curr_page_data[:songs_data].each do |x|
        songs_data_count += 1
        yield x
      end

      # now = Time.now.utc
      # File.write("#{now.iso8601}.json", JSON.pretty_generate(curr_page_data[:songs_data]))

      break if next_from == ''
    end

    nil
  end
end

module GetSongUrls
  def self.call(songs_data:, cookie:)
    results = []
    songs_data.each_with_index.each_slice(5) do |pairs|
      puts "progress: #{pairs[0][1]} / #{songs_data.size}"
      slice = pairs.map(&:first)
      all_ids = slice.map { |x| [x[1], x[0], x[13].split('/')[2], x[13].split('/')[5]] }

      ids = all_ids
        .select { |row| row.all? { |x| !x.to_s.empty? } }
        .map { |x| x.join('_') }

      bad_ids = all_ids
        .select { |row| !row.all? { |x| !x.to_s.empty? } }

      puts "MISSING HASH, SKIPPING: #{bad_ids.size}: #{bad_ids.inspect}" unless bad_ids.empty?

      next if ids.empty?

      url = 'https://vk.com/al_audio.php?act=reload_audio'
      params = {
        'al' => "1",
        'ids' => ids.join(','),
      }

      headers = {
        'User-Agent' => 'Mozilla Linux Firefox',
        'Cookie' => cookie,
        'X-Requested-With' => 'XMLHttpRequest',
      }

      response = LoadWithPost.call(url: url, data: params, headers: headers)
      delay = 10
      puts "sleep #{delay} start"
      sleep delay
      puts "sleep #{delay} finish"

      begin
        result = JSON.parse(response)['payload'][1][0].map { |x| [x[0], x[1], x[2]] }
      rescue StandardError => e
        require 'pry'; binding.pry
      end
      results.concat(result)
    end

    results
  end
end

module UnmaskUrl
  def self.call(url:)
    raise 'wtf' if url.include?("'")
    # puts "echo '#{url}' | node '#{File.join(File.dirname(__FILE__), 'unmask.js')}'"
    result = `echo '#{url}' | node '#{File.join(File.dirname(__FILE__), 'unmask.js')}'`

    raise 'error' if result.empty? || result == url

    result = URI(result)
    result.query = 'long_chunk=1'
    result = result.to_s

    result.to_s
  end
end

module LoadFragments
  def self.call(headers:)
    cache = {}
    headers.map do |x|
      downloaded = DownloadClient.call(uri: x[:url])
      if x[:key_method]
        key = cache[x[:key_uri]] ||= DownloadClient.call(uri: x[:key_uri])

        decrypted = DecryptFragment.call(
          encrypted: downloaded, key: key, sequence_number: x[:seq],
        )
      else
        decrypted = downloaded
      end

      decrypted
    end
  end
end

module DecryptFragment
  def self.call(encrypted:, key:, sequence_number:)
    # log 'encrypted.bytesize'
    # log encrypted.bytesize

    # log 'key.bytesize'
    # log key.bytesize
    raise 'wrong key' unless key.bytesize == 16

    iv = [0, Integer(sequence_number)].pack('Q>*')
    # log 'iv.bytesize'
    # log iv.bytesize
    raise 'wrong iv' unless iv.bytesize == 16

    decipher = OpenSSL::Cipher::AES.new(128, :CBC)
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv

    plain = decipher.update(encrypted) + decipher.final
    # log 'plain.bytesize'
    # log plain.bytesize

    magics = plain.each_byte.each_slice(188).map(&:first).map(&:ord)
    # log 'magics'
    # log magics.uniq.sort.map { |x| x.chr.unpack('H*').first }.inspect
    raise 'wrong decrypt result' unless magics.all? { |x| x == 0x47 }

    return plain
  end

  def self.log(string)
    # puts string
  end
end

module ParseM3U8
  def self.call(lines:)
    results = []
    sequence_number = -1
    key_method = nil
    key_uri = nil
    lines.each do |line|
      ignored_lines = [
        /^#EXTM3U$/,
        /^#EXT-X-TARGETDURATION.*$/,
        /^#EXT-X-ALLOW-CACHE.*$/,
        /^#EXT-X-PLAYLIST-TYPE.*$/,
        /^#EXT-X-VERSION.*$/,
        /^#EXTINF.*$/,
        /^#EXT-X-ENDLIST.*$/,
      ]

      if ignored_lines.any? { |x| line.match(x) }
        # log 'ignoring'

        next
      end

      match = line[/^#EXT-X-MEDIA-SEQUENCE:(.*)$/, 1]
      if match
        sequence_number = Integer(match)
        log "set sequence: #{match}"

        next
      end

      match = line[/#EXT-X-KEY:(.*)/, 1]
      if match
        params = match.split(',').map { |x| x.split('=', 2) }.to_h
        raise 'unknown params' unless (params.keys - ['METHOD', 'URI']).empty?

        case params['METHOD']
        when 'AES-128'
          uri = params['URI'].gsub(/^"/, '').gsub(/"$/, '')
          raise 'unknown uri' unless uri

          log "set key method aes128"
          key_method = params['METHOD']
          key_uri = uri
        when 'NONE'
          log 'set key method nil'
          key_method = nil
          key_uri = nil
        else
          raise 'unknown method'
        end

        next
      end

      if line[0] != '#'
        results << { url: line, seq: sequence_number, key_method: key_method, key_uri: key_uri }
        log "chunk #{sequence_number} parsed"
        sequence_number += 1

        next
      end

      ap line
      raise 'unknown line type'
    end

    results
  end

  def self.log(string)
    # puts string
  end
end

module DownloadClient
  def self.call(uri:)
    uri = URI(uri)
    uri.query = URI.encode_www_form('extra' => '', 'long_chunk' => '1')
    log "DOWNLOAD: #{uri}"
    result = Net::HTTP.get(uri)

    result
  end

  def self.log(string)
    # puts string
  end
end

module DownloadM3U8Url
  def self.call(base_url:)
    m3u8_data = DownloadClient.call(uri: base_url).split("\n").map(&:chomp)

    data_chunks = ParseM3U8.call(lines: m3u8_data)

    data_chunks.each do |x|
      x[:url] = URI.join(base_url, x[:url]).to_s
    end

    fragments = LoadFragments.call(headers: data_chunks)

    fragments.join
  end
end

module DownloadMp3Url
  def self.call(base_url:)
    LoadGeneric.call(url: base_url, cookie: '')
  end
end

module DownloadMusicFile
  def self.call(url:)
    puts "#{self}(url: #{url})"
    result =
      if url.include?('.m3u8')
        DownloadM3U8Url.call(base_url: url)
      elsif url.include?('.mp3')
        DownloadMp3Url.call(base_url: url)
      else
        require 'pry'; binding.pry
      end
    puts "#{self}(url: #{url}) finish"
    result
  end
end
