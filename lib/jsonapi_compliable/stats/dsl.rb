module JsonapiCompliable
  module Stats
    class DSL
      attr_reader :config

      def self.defaults
        {
          count: ->(scope, attr) { scope.count },
          average: ->(scope, attr) { scope.average(attr).to_f },
          sum: ->(scope, attr) { scope.sum(attr) },
          maximum: ->(scope, attr) { scope.maximum(attr) },
          minimum: ->(scope, attr) { scope.minimum(attr) }
        }
      end

      def initialize
        @config = {}
      end

      def method_missing(meth, *args, &blk)
        @config[meth] = blk
      end

      def count!
        @config[:count] = self.class.defaults[:count]
      end

      def sum!
        @config[:sum] = self.class.defaults[:sum]
      end

      def average!
        @config[:average] = self.class.defaults[:average]
      end

      def maximum!
        @config[:maximum] = self.class.defaults[:maximum]
      end

      def minimum!
        @config[:minimum] = self.class.defaults[:minimum]
      end
    end
  end
end
