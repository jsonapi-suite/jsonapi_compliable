class IncludeDSL
  attr_accessor :name, :as, :only, :array, :_data, :_includes, :_assign

  def initialize
    @_includes = {}
  end

  def data(&blk)
    @_data = blk
  end

  def assign(&blk)
    @_assign = blk
  end

  def allowed?(action_name)
    @only.nil? || @only.include?(action_name)
  end

  def allow_sideload(association_name, only: nil, array: true, as: nil, &blk)
    dsl = IncludeDSL.new
    dsl.name = association_name
    dsl.only = only
    dsl.as = as || association_name
    dsl.array = array
    dsl.instance_eval(&blk)
    @_includes[association_name] = dsl
  end

  # Todo adapter, non-AR
  # NOTE - not reflecting b/c may be array of STI
  def has_many(association_name, scope:, foreign_key:, primary_key: :id, as: nil, &blk)
    as ||= association_name

    allow_sideload association_name, array: true, as: as do
      data do |parents|
        parent_ids = parents.map { |p| p.send(primary_key) }
        scope.call.where(foreign_key => parent_ids)
      end

      assign do |parents, children|
        parents.each do |parent|
          relevant_children = children.select { |c| c.send(foreign_key) == parent.send(primary_key) }
          parent.send(:"#{as}=", relevant_children)
        end
      end

      instance_eval(&blk) if blk
    end
  end

  def belongs_to(association_name, scope:, foreign_key:, primary_key: :id, array: false, as: nil, &blk)
    as ||= association_name

    allow_sideload association_name, as: as, array: array do
      data do |parents|
        parent_ids = parents.map { |p| p.send(foreign_key) }
        scope.call.where(primary_key => parent_ids)
      end

      assign do |parents, children|
        parents.each do |parent|
          relevant_child = children.find { |c| parent.send(foreign_key) == c.send(primary_key) }
          relevant_child = Array(relevant_child) if array
          parent.send(:"#{as}=", relevant_child)
        end
      end

      instance_eval(&blk) if blk
    end
  end

  # TODO - 'through' option is AR-specific
  # difficult to do non-ar maybe
  # maybe pass ids to scope
  def has_and_belongs_to_many(association_name, scope:, foreign_key:, primary_key: :id, as: nil, &blk)
    through = foreign_key.keys.first
    fk      = foreign_key.values.first
    as    ||= association_name

    allow_sideload association_name, as: as, array: true do
      data do |parents|
        scope.call.joins(through).where(through => { fk => parents.map { |p| p.send(primary_key) } })
      end

      assign do |parents, children|
        parents.each do |parent|
          relevant_children = children.select { |c| c.send(through).any? { |ct| ct.send(fk) == parent.send(primary_key) } }
          parent.send(:"#{as}=", relevant_children)
        end
      end

      instance_eval(&blk) if blk
    end
  end

  def has_one(association_name, scope:, foreign_key:, primary_key: :id, as: nil, array: false, &blk)
    as ||= association_name

    allow_sideload association_name, as: as, array: array do
      data do |parents|
        parent_ids = parents.map { |p| p.send(primary_key) }
        scope.call.where(foreign_key => parent_ids)
      end

      assign do |parents, children|
        parents.each do |parent|
          relevant_child = children.find { |c| c.send(foreign_key) == parent.send(primary_key) }
          relevant_child = Array(relevant_child) if array
          parent.send(:"#{as}=", relevant_child)
        end
      end

      instance_eval(&blk) if blk
    end
  end

  # TODO - incorporate show/index
  def to_hash
    hash = {}
    @_includes.each_pair do |assn_name, dsl|
      hash[assn_name] = dsl.to_hash
    end
    hash
  end

  def load!(object, scrubbed_includes)
    @_includes.each_pair do |association_name, include_dsl|
      next unless scrubbed_includes.has_key?(association_name)

      results = include_dsl._data.call(Array(object))
      include_dsl.load!(Array(results), scrubbed_includes[association_name])

      include_dsl._assign.call(Array(object), results)
    end
  end
end
