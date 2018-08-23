module JsonapiCompliable
  # Apply filtering logic to the scope
  #
  # If the user requests to filter a field that has not been whitelisted,
  # a +JsonapiCompliable::Errors::BadFilter+ error will be raised.
  #
  #   allow_filter :title # :title now whitelisted
  #
  # If the user requests a filter field that has been whitelisted, but
  # does not pass the associated `+:if+ clause, +BadFilter+ will be raised.
  #
  #   allow_filter :title, if: :admin?
  #
  # This will also honor filter aliases.
  #
  #   # GET /posts?filter[headline]=foo will filter on title
  #   allow_filter :title, aliases: [:headline]
  #
  # @see Adapters::Abstract#filter
  # @see Adapters::ActiveRecord#filter
  # @see Resource.allow_filter
  class Scoping::Filter < Scoping::Base
    include Scoping::Filterable

    # Apply the filtering logic.
    #
    # Loop and parse all requested filters, taking into account guards and
    # aliases. If valid, call either the default or custom filtering logic.
    # @return the scope we are chaining/modifying
    def apply
      raise JsonapiCompliable::Errors::RequiredFilter.new(missing_required_filters) unless required_filters_provided?
      each_filter do |filter, value|
        @scope = filter_scope(filter, value)
      end

      @scope
    end

    private

    # If there's custom logic, run it, otherwise run the default logic
    # specified in the adapter.
    def filter_scope(filter, value)
      if custom_scope = filter.values.first[:filter]
        custom_scope.call(@scope, value, resource.context)
      else
        resource.adapter.filter(@scope, filter.keys.first, value)
      end
    end

    def each_filter
      filter_param.each_pair do |param_name, param_value|
        filter = find_filter!(param_name.to_sym)
        value  = param_value
        value  = parse_string_arrays(value)
        value  = normalize_string_values(value)
        yield filter, value
      end
    end

    # foo,bar,baz becomes ["foo", "bar", "baz"]
    # {{foo}} becomes ["foo"]
    # {{foo,bar}},baz becomes ["foo,bar", "baz"]
    #
    # JSON of
    # {{{ "id": 1 }}} becomes { 'id' => 1 }
    def parse_string_arrays(value)
      if value.is_a?(String)# && value[0..2] != '{{{'
        # Escaped JSON
        if value[0..2] == '{{{'
          value = value.sub('{{', '').sub('}}', '')
          value = JSON.parse(value)
        else
          # Find the quoted strings
          quotes = value.scan(/{{.*?}}/)
          # remove them from the rest
          quotes.each { |q| value.gsub!(q, '') }
          # remove the quote characters from the quoted strings
          quotes.each { |q| q.gsub!('{{', '').gsub!('}}', '') }
          # merge everything back together into an array
          value = Array(value.split(',')) + quotes
          # remove any blanks that are left
          value.reject! { |v| v.length.zero? }
          value = value[0] if value.length == 1
        end
      end
      value
    end

    # Convert a string of "true" to true, etc
    #
    # NB - avoid Array(value) here since we might want to
    # return a single element instead of array
    def normalize_string_values(value)
      if value.is_a?(Array)
        value.map { |v| normalize_string_value(v) }
      else
        normalize_string_value(value)
      end
    end

    def normalize_string_value(value)
      case value
      when 'true' then true
      when 'false' then false
      when 'nil', 'null' then nil
      else
        value
      end
    end
  end
end
