require 'awesome_print'

PHRASAL_VERBS = File.readlines('phrasal.txt').map { |x| x.strip.split(' ') }
# PHRASAL_VERBS = File.readlines('phrasal_small.txt').map { |x| x.strip.split(' ') }

def downcase_words
  @result ||=
    begin
      articles = %w[a an the]
      conjunctions = %w[and but or nor]
      prepositions = %w[at by for from in into of off on onto out over to up with]
      as = %w[as]
      [*articles, *conjunctions, *prepositions, *as]
    end
end

def is_part_of_phrasal(words, idx)
  # require 'pry'; binding.pry
  target = words[idx]
  return false unless downcase_words.include?(target)
  return false if idx == 0 || idx == words.size - 1

  PHRASAL_VERBS.each do |verb_words|
    verb_words_idx = verb_words.index(target)
    next unless verb_words_idx

    occurence_index = idx - verb_words_idx
    next unless occurence_index >= 0 && occurence_index + verb_words.size - 1 < words.size

    fragment = words[occurence_index, verb_words.size]
    raise 'wtf' unless fragment.size == verb_words.size

    match = verb_words.size.times.map do |i|
      if i == 0
        fragment[i].include?(verb_words[i])
      else
        fragment[i] == verb_words[i]
      end
    end

    return true if match.all?
  end

  false
end

def is_part_of_phrasal_all(words)
  words.size.times.map do |i|
    is_part_of_phrasal(words, i)
  end
end

def song_capitalise(string)
  words = string.strip.split(/\s+/).map(&:downcase)
  marks = words.map { |x| true }

  words.each_with_index do |w, i|
    # require 'pry'; binding.pry
    marks[i] = false if downcase_words.include?(w)
  end

  words.size.times do |i|
    marks[i] = true if is_part_of_phrasal(words, i)
  end

  marks[0] = true
  marks[-1] = true

  words.zip(marks).map { |w, m| m ? w.capitalize : w.downcase }.join(' ')
end


if $PROGRAM_NAME == __FILE__
  test_songs = [
    'i will hold on to you',
    'she gives up on me',
    'why do you give yourself up again',
  ]
  test_songs.each do |test_song|
    ap song_capitalise(test_song)
    ap is_part_of_phrasal_all(test_song.split(' '))
  end
end
