# jsonapi do
#   scope: -> { Author.all }
#
#   use_adapter ActiveRecord
#
#   paginate { } # override
#
#   from_sideload :things do |things|
#   end # belongs_to?
#
#   allow_sideload :bills do
#     use_adapter Bill # from bills controller
#     # clone then customize?
#   end
# end

# def index
#   jsonapi_scope(AuthorResource)
# end
#
# OR, just say this is not worth it and ?include=recent_bills

#jsonapi do
  #use_adapter Author

  #has_many :bills, adapter: BillQuery do
    # custom logic just for authors endpoint
  #end
#end

#class BillQuery < Query
  #adapter ActiveRecordAdapter do
    #default_scope { Bill.all }

    #belongs_to :author, foreign_key: :author_id

    #paginate { } # override
  #end
#end

module JsonapiCompliable
  class Query
    def initialize(controller)
      @controller = controller
    end

    # defaults per_page etc as well
    def to_hash
      hash = {}
      ([:default] + dsl.association_names).each do |name|
        hash[name] = default_hash
      end

      parse_filter(hash)
      parse_sort(hash)
      parse_pagination(hash)
      # TODO fields, extra_fields, ...stats?

      hash
    end

    private

    def params
      @controller.params
    end

    def dsl
      @controller._jsonapi_compliable
    end

    def association?(name)
      dsl.association_names.include?(name)
    end

    def default_hash
      { filter: {}, sort: [], page: {} }
    end

    def parse_filter(hash)
      if filter = params[:filter]
        filter.each_pair do |key, value|
          key = key.to_sym

          if association?(key)
            hash[key][:filter].merge!(value)
          else
            hash[:default][:filter][key] = value
          end
        end
      end
    end

    def parse_sort(hash)
      if sort = params[:sort]
        sorts = sort.split(',')
        sorts.each do |s|
          if s.include?('.')
            type, attr = s.split('.')
            if type.starts_with?('-')
              type = type.sub('-', '')
              attr = "-#{attr}"
            end

            hash[type.to_sym][:sort] << sort_attr(attr)
          else
            hash[:default][:sort] << sort_attr(s)
          end
        end
      end
    end

    def parse_pagination(hash)
      if pagination = params[:page]
        pagination.each_pair do |key, value|
          if [:number, :size].include?(key)
            hash[:default][:page][key] = value
          else
            hash[key][:page] = value
          end
        end
      end
    end

    def sort_attr(attr)
      value = attr.starts_with?('-') ? :desc : :asc
      key   = attr.sub('-', '').to_sym

      { key => value }
    end
  end
end
