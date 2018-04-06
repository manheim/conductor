class MessageSearcher
  attr_accessor :options

  def initialize(options)
    self.options = options
  end

  def message_ids
    words = parse_search_term options[:search_term]
    boolean_search = convert_words_to_boolean_search words
    search(boolean_search)
  end

  def search(boolean_search)
    Parallel.map([SearchText, AlternateSearchText], in_threads: 2) do |clazz|
      ActiveRecord::Base.connection_pool.with_connection do
        search_from(clazz, boolean_search)
      end
    end.flatten.uniq
  end

  def parse_search_term search_term
    search_term = " " + search_term + " "

    words = search_term
      .scan(/(?:\s[\+-]){0,1}[[:word:]]+(?:\*\s){0,1}/)
      .map(&:strip)

    words.reject do |word|
      stop_words.any? do |stop_word|
        word.match(/^(?:[\+-]){0,1}#{stop_word}(?:\*){0,1}$/)
      end
    end
  end

  def stop_words
    @stop_words ||= Settings.search_text_ignore_words.split(",")
  end

  def convert_words_to_boolean_search words
    words.reject do |word|
      word.size < 3
    end.map do |word|
      if word.starts_with?("-") || word.starts_with?("+")
        word
      else
        "+#{word}"
      end
    end.join(" ")
  end

  protected

  def search_from(clazz, boolean_search)
    clazz.where(
      "match(text) AGAINST (? IN BOOLEAN MODE)",
      boolean_search
    ).limit(
      options[:max_full_text_search_results]
    ).pluck(:message_id)
  end
end
