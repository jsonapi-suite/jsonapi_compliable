require 'spec_helper'

RSpec.describe 'sideloading via ActiveRecord', type: :controller do
  include SideloadHelper
  include_context "sideloading data"

  # Ensure we don't use default AR to fetch relations
  class AuthorNoRelations < Author
    attr_accessor :bestselling_book,
      :special_state,
      :serious_hobbies
  end

  # Make work for cong staffer
  # Other scopes ?sort[assn]
  # General refactor - Adapters

  controller(ApplicationController) do
    jsonapi do
      includes do
        has_many :books, scope: -> { Book.all }, foreign_key: :author_id do
          belongs_to :genre, scope: -> { Genre.all }, foreign_key: :genre_id
        end

        has_many :top_sellers,
          scope: -> { Book.where(["sales >= ?", 50]) },
          foreign_key: :author_id,
          as: :books
        has_one :bestselling_book,
          scope: -> { Book.bestseller.order(sales: :desc).limit(1) },
          foreign_key: :author_id,
          as: :books,
          array: true

        belongs_to :state, scope: -> { State.all }, foreign_key: :state_id
        belongs_to :special_state,
          scope: -> { State.all },
          foreign_key: :state_id,
          as: :state

        has_and_belongs_to_many :hobbies,
          scope: -> { Hobby.all },
          foreign_key: { author_hobbies: :author_id }
        has_and_belongs_to_many :serious_hobbies,
          scope: -> { Hobby.all }, # TODO - serious on metadata?
          foreign_key: { author_hobbies: :author_id },
          as: :hobbies

        has_one :bio, scope: -> { Bio.all }, foreign_key: :author_id

        polymorphic :dwelling,
          group_by: proc { |author| author.dwelling_type },
          foreign_key: :dwelling_id,
          scopes: {
            'House' => -> { House.all },
            'Condo' => -> { Condo.all }
          }
      end
    end

    def index
      render_jsonapi(AuthorNoRelations.all, class: SerializableAuthor)
    end
  end

  include_examples "API sideloading"

  context 'when filtering association' do
    it 'filters the association correctly' do
      get :index, params: { include: 'books', filter: { books: { id: better_seller.id } } }
      expect(json_includes('books')[0]['id']).to eq(better_seller.id.to_s)
    end
  end

  context 'when "as" subrelation' do
    context 'when has_one' do
      it 'sideloads the relevant subrelation to the correct key' do
        get :index, params: { include: 'bestselling_book' }

        expect(json_included_types).to match_array(%w(books))
        expect(json_includes('books')[0]['id']).to eq(bestseller.id.to_s)
      end

      context 'as an array' do
        it 'sideloads the relevant subrelation to the correct key' do
          get :index, params: { include: 'bestselling_book' }

          expect(json_included_types).to match_array(%w(books))
          expect(json_includes('books')[0]['id']).to eq(bestseller.id.to_s)

          # should cast as array
          expect(json['data'].first['relationships']['books']['data']).to be_a(Array)
        end
      end
    end

    context 'when has_many' do
      it 'sideloads the relevant subrelation to the correct key' do
        get :index, params: { include: 'top_sellers' }

        expect(json_included_types).to match_array(%w(books))
        expect(json_includes('books').map { |b| b['id'] })
          .to eq([better_seller.id.to_s, bestseller.id.to_s])
      end
    end

    context 'when belongs_to' do
      it 'sideloads the relevant subrelation to the correct key' do
        get :index, params: { include: 'special_state' }

        expect(json_included_types).to match_array(%w(states))
      end
    end

    context 'when HABTM' do
      it 'sideloads the relevant subrelation to the correct key' do
        get :index, params: { include: 'serious_hobbies' }

        expect(json_included_types).to match_array(%w(hobbies))
      end
    end
  end
end
