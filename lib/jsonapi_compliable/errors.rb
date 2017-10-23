module JsonapiCompliable
  module Errors
    class ValidationError < RuntimeError; end
    class BadRequest < RuntimeError; end
    class BadFilter < BadRequest; end

    class UnsupportedPageSize < BadRequest
      def initialize(size, max)
        @size, @max = size, max
      end

      def message
        "Requested page size #{@size} is greater than max supported size #{@max}"
      end
    end

    class StatNotFound < BadRequest
      def initialize(attribute, calculation)
        @attribute = attribute
        @calculation = calculation
      end

      def message
        "No stat configured for calculation #{pretty(@calculation)} on attribute #{pretty(@attribute)}"
      end

      private

      def pretty(input)
        if input.is_a?(Symbol)
          ":#{input}"
        else
          "'#{input}'"
        end
      end
    end
  end
end
