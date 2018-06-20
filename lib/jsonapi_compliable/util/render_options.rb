module JsonapiCompliable
  module Util
    # Generate the options we end up passing to {{http://jsonapi-rb.org jsonapi-rb}}
    # @api private
    class RenderOptions
      def self.generate(query_hash, overrides = {})
        fields = query_hash[:fields].dup
        extra_fields = query_hash[:extra_fields]

        # Ensure fields doesnt clobber extra fields
        extra_fields.each do |k,v|
          fields[k] = fields[k] + v if fields[k]
        end

        options            = {}
        options[:class]    = inferrer
        options[:include]  = query_hash[:include]
        options[:fields]   = fields
        options.merge!(overrides)
        options[:meta]   ||= {}
        options[:expose] ||= {}
        options[:expose][:extra_fields] = extra_fields
        options
      end

      def self.inferrer
        ::Hash.new do |h, k|
          names = k.to_s.split('::')
          klass = names.pop
          serializer_name = [*names, "Serializable#{klass}"].join('::')
          serializer = serializer_name.safe_constantize
          if serializer
            h[k] = serializer
          else
            raise Errors::MissingSerializer.new(k, serializer_name)
          end
        end
      end
      private_class_method :inferrer
    end
  end
end
