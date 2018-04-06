class ShardIdProvider
  attr_reader :settings, :http_headers, :body

  def initialize(options)
    @settings = options[:settings]
    @http_headers = options[:headers]
    @body = options[:body]
  end

  def shard_id
    if settings[:extract_shard_enabled]
      if settings[:extract_shard_content_type] == "json"
        hash = JSON.parse(body)
        shard_id_from_hash(hash)
      elsif settings[:extract_shard_content_type] == "xml"
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!
        node = doc.xpath(settings[:extract_shard_path])
        scrub_shard(node.children.text)
      end
    elsif settings[:autogenerate_shard_id]
      rand(1..settings[:autogenerate_shard_id_range])
    else
      http_headers[settings[:shard_tag].to_s.downcase.camelize]
    end
  end

  protected

  def shard_id_from_hash(hash)
    keys = settings[:extract_shard_path].split "."
    keys.each do |key|
      hash = hash.try(:[], key)
    end

    scrub_shard(hash)
  end

  def scrub_shard(value)
    value.to_s.last(190)
  end
end
