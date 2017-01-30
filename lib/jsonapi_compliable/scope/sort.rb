module JsonapiCompliable
  class Scope::Sort < Scope::Base
    def custom_scope
      dsl.sorting
    end

    def apply_standard_scope
      @scope.order(attribute => direction)
    end

    def apply_custom_scope
      custom_scope.call(@scope, attribute, direction)
    end

    private

    def sort_param
      @sort_param ||= params[:sort][0] || dsl.default_sort
    end

    # TODO multisort
    def direction
      sort_param.values.last
    end

    def attribute
      sort_param.keys.first
    end
  end
end
