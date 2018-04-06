class GenericMessageIndexExtractor
  attr_accessor :number_of_characters, :words, :message, :extraction_direction

  ALLOWED_DIRECTIONS = [
    "forwards",
    "backwards",
    "bidirectional"
  ]

  def initialize(options)
    self.number_of_characters = options[:number_of_characters]
    self.words = options[:words]
    self.message = options[:message]
    self.extraction_direction = options[:extraction_direction]
    unless ALLOWED_DIRECTIONS.include?(extraction_direction)
      raise ArgumentError.new("extraction_direction must be one of #{ALLOWED_DIRECTIONS}")
    end
  end

  def extract
    extract_parts.join(" ")
  end

  protected

  def extract_parts
    words.map do |word|
      extract_body_for_word(word) + extract_headers_for_word(word)
    end.flatten
  end

  def extract_body_for_word(word)
    extract_fragment_from_string(message.body, word)
  end

  def extract_headers_for_word(word)
    extract_fragment_from_string(message.headers, word)
  end

  def extract_fragment_from_string text, word
    return [] if text.blank? || word.blank?
    word = Regexp.escape(word)

    if extraction_direction == 'forwards'
      extraction = text.scan(/#{word}.{0,#{number_of_characters}}/)
    elsif extraction_direction == 'backwards'
      extraction = text.scan(/.{0,#{number_of_characters}}#{word}/)
    elsif extraction_direction == 'bidirectional'
      extraction = text.scan(/.{0,#{number_of_characters}}#{word}.{0,#{number_of_characters}}/)
    end

    extraction
  end
end
