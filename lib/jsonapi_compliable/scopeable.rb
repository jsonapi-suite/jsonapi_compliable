# Todo rename to scope
module JsonapiCompliable
  class Scopeable
    attr_reader :object

    def self.build(scope, query_hash, dsl,
                  filter: true,
                  includes: true,
                  paginate: true,
                  extra_fields: true,
                  sort: true)
      #query_hash = Query.new(self).to_hash[:default]
      scope = JsonapiCompliable::Scope::DefaultFilter.new(dsl, query_hash, scope).apply
      scope = JsonapiCompliable::Scope::Filter.new(dsl, query_hash, scope).apply if filter
      scope = JsonapiCompliable::Scope::ExtraFields.new(dsl, query_hash, scope).apply if extra_fields
      scope = JsonapiCompliable::Scope::Sort.new(dsl, query_hash, scope).apply if sort
      # This is set before pagination so it can be re-used for stats
      # TODO @_jsonapi_scope = scope
      scope = JsonapiCompliable::Scope::Paginate.new(dsl, query_hash, scope).apply if paginate

      new(scope, query_hash, dsl)
    end

    def initialize(object, params, controller)
      @object = object
      @controller = controller
      @params = params
    end

    # Todo alias to_a, etc etc
    def resolve
      if JsonapiCompliable::Util::Pagination.zero?(@controller.params)
        return []
      end

      include_params = Util::IncludeParams.scrub(@controller)

      # TODO - resolve config option
      @object = @object.to_a if @object.is_a?(ActiveRecord::Relation)

      if sideloads = @controller._jsonapi_compliable.sideloads
        sideloads.load!(@object, include_params, @params)
      end

      Array(@object)
    end
  end
end
