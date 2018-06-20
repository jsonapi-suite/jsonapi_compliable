if ENV["APPRAISAL_INITIALIZED"]
  RSpec.describe 'sideload whitelist', type: :controller do
    module SideloadWhitelist
      class ApplicationResource < JsonapiCompliable::Resource
        self.adapter = JsonapiCompliable::Adapters::ActiveRecord::Base.new
      end

      class GenreResource < ApplicationResource
        self.type = :genres
        self.model = Genre
      end

      class BookResource < ApplicationResource
        self.type = :books
        self.model = Book

        allow_filter :id

        belongs_to :genre
      end

      class AuthorResource < ApplicationResource
        self.type = :authors
        self.model = Author

        has_many :books
      end
    end

    controller(ApplicationController) do
      jsonapi resource: SideloadWhitelist::AuthorResource

      def index
        render jsonapi: Author.all
      end
    end

    def json
      JSON.parse(response.body)
    end

    def json_includes(type)
      json['included'].select { |i| i['type'] == type }
    end

    let!(:author) { Author.create!(first_name: 'Stephen') }
    let!(:book) { Book.create!(title: 'The Shining', author: author, genre: genre) }
    let!(:genre) { Genre.create!(name: 'Horror') }

    context 'when no sideload whitelist' do
      it 'allows loading all relationships' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to_not be_blank
      end
    end

    context 'when a sideload whitelist' do
      before do
        controller.class.sideload_whitelist({
          index: [:books],
          show: { books: :genre }
        })
      end

      it 'restricts what sideloads can be loaded' do
        get :index, params: { include: 'books.genre' }
        expect(json_includes('books')).to_not be_blank
        expect(json_includes('genres')).to be_blank
      end
    end
  end
end
