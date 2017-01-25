# Todo rename to scope
module JsonapiCompliable
  class Scopeable
    attr_reader :object

    def initialize(object, controller)
      @object = object
      @controller = controller
    end

    # Todo alias to_a, etc etc
    def resolve(array = true)
      if JsonapiCompliable::Util::Pagination.zero?(@controller.params)
        return (array ? [] : nil)
      end

      include_params = Util::IncludeParams.scrub(@controller)

      # TODO - resolve config option
      @object = @object.to_a if @object.is_a?(ActiveRecord::Relation)

      if sideloads = @controller._jsonapi_compliable.sideloads
        sideloads.load!(@object, include_params)
      end

      if array and !@object.is_a?(Array)
        @object = [@object]
      elsif @object.is_a?(Array) and !array
        @object = @object[0]
      end

      @object
    end
  end
end
