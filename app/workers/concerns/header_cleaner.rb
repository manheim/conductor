module Concerns
  module HeaderCleaner
    extend ActiveSupport::Concern

    included do
      send(:include, InstanceMethods)
    end

    module InstanceMethods
      def auth_cleaner dirty_hash
        dirty_hash.reduce({}) do |acc, kv|
          if kv[0] !~ /authorization/i
            if kv[1].is_a? Hash
              new_value = auth_cleaner(kv[1])
            else
              new_value = kv[1]
            end
            acc[kv[0]]  = new_value unless kv[1].is_a? Faraday::Response
          end
          acc
        end
      end
    end
  end
end
