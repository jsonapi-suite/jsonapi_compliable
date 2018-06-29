if ENV['APPRAISAL_INITIALIZED']
  RSpec.describe 'integrated resources and adapters', type: :controller do
    controller(ApplicationController) do
      def index
        authors = Legacy::AuthorResource.all(params)
        render jsonapi: authors
      end

      def show
        author = Legacy::AuthorResource.find(params)
        render jsonapi: author
      end
    end

    let!(:author1) do
      Legacy::Author.create! first_name: 'Stephen',
        state: state,
        organization: org1,
        dwelling: house
    end
    let!(:author2) do
      Legacy::Author.create! first_name: 'George',
        dwelling: condo
    end
    let!(:book1)   { Legacy::Book.create!(author: author1, genre: genre, title: 'The Shining') }
    let!(:book2)   { Legacy::Book.create!(author: author1, genre: genre, title: 'The Stand') }
    let!(:state)   { Legacy::State.create!(name: 'Maine') }
    let(:org1)     { Legacy::Organization.create!(name: 'Org1', children: [org2]) }
    let(:org2)     { Legacy::Organization.create!(name: 'Org2') }
    let!(:bio)     { Legacy::Bio.create!(author: author1, picture: 'imgur', description: 'author bio') }
    let!(:genre)   { Legacy::Genre.create!(name: 'Horror') }
    let!(:hobby1)  { Legacy::Hobby.create!(name: 'Fishing', authors: [author1]) }
    let!(:hobby2)  { Legacy::Hobby.create!(name: 'Woodworking', authors: [author1, author2]) }
    let!(:house)   { Legacy::House.new(name: 'Cozy', state: state) }
    let!(:condo)   { Legacy::Condo.new(name: 'Modern') }

    def ids_for(type)
      json_includes(type).map { |i| i['id'].to_i }
    end

    def json_included_types
      json['included'].map { |i| i['type'] }.uniq
    end

    def json_includes(type)
      json['included'].select { |i| i['type'] == type }
    end

    def json_ids
      json['data'].map { |d| d['id'].to_i }
    end

    def json
      JSON.parse(response.body)
    end

    it 'allows basic sorting' do
      get :index, params: { sort: '-id' }
      expect(json_ids).to eq([author2.id, author1.id])
    end

    it 'allows basic pagination' do
      get :index, params: { page: { number: 2, size: 1 } }
      expect(json_ids).to eq([author2.id])
    end

    it 'allows whitelisted filters (and other configs)' do
      get :index, params: { filter: { first_name: 'George' } }
      expect(json_ids).to eq([author2.id])
    end

    it 'allows basic sideloading' do
      get :index, params: { include: 'books' }
      expect(json_included_types).to match_array(%w(books))
    end

    it 'allows nested sideloading' do
      get :index, params: { include: 'books.genre' }
      expect(json_included_types).to match_array(%w(books genres))
    end

    context 'when hitting #show' do
      subject(:make_request) do
        if Rails::VERSION::MAJOR >= 5
          get :show, params: { id: id, include: 'books' }
        else
          get :show, id: id, params: {
            id: id, include: 'books'
          }
        end
      end

      let(:id) { author1.id.to_s }

      it 'works' do
        make_request
        expect(json['data']['id']).to eq(author1.id.to_s)
        expect(json['data']['attributes']).to eq({ 'first_name' => 'Stephen' })
        expect(json_included_types).to match_array(%w(books))
      end

      context 'and record not found' do
        let(:id) { '99999' }

        it 'raises not found error' do
          expect {
            make_request
          }.to raise_error(JsonapiCompliable::Errors::RecordNotFound)
        end
      end
    end

    context 'when passing sparse fieldsets on primary data' do
      context 'and sideloading' do
        it 'is able to sideload without adding the field' do
          get :index, params: { fields: { authors: 'first_name' }, include: 'books' }
          expect(json['data'][0]['relationships']).to be_present
          expect(json_included_types).to match_array(%w(books))
        end
      end
    end

    context 'sideloading has_many' do
      it 'can sideload' do
        get :index, params: { include: 'books' }
        expect(ids_for('books')).to eq([book1.id, book2.id])
      end

      context 'when paginating the sideload' do
        let(:request) do
          get :index, params: { include: 'books', page: { books: { size: 1, number: 2 } } }
        end

        context 'and only 1 parent' do
          before do
            author2.destroy
          end

          it 'works' do
            request
            expect(ids_for('books')).to eq([book2.id])
          end
        end

        context 'and > 1 parents' do
          it 'raises error' do
            expect {
              request
            }.to raise_error(JsonapiCompliable::Errors::UnsupportedPagination)
          end
        end
      end

      it 'allows sorting of sideloaded resource' do
        get :index, params: { include: 'books', sort: '-books.id' }
        expect(ids_for('books')).to eq([book2.id, book1.id])
      end

      it 'allows filtering of sideloaded resource' do
        get :index, params: { include: 'books', filter: { books: { id: book2.id } } }
        expect(ids_for('books')).to eq([book2.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'books', extra_fields: { books: 'alternate_title' } }
        book = json_includes('books')[0]['attributes']
        expect(book['title']).to be_present
        expect(book['pages']).to be_present
        expect(book['alternate_title']).to eq('alt title')
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'books', fields: { books: 'pages' } }
        book = json_includes('books')[0]['attributes']
        expect(book).to_not have_key('title')
        expect(book).to_not have_key('alternate_title')
        expect(book['pages']).to eq(500)
      end

      it 'allows extra fields and sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'books', fields: { books: 'pages' }, extra_fields: { books: 'alternate_title' } }
        book = json_includes('books')[0]['attributes']
        expect(book).to have_key('pages')
        expect(book).to have_key('alternate_title')
        expect(book).to_not have_key('title')
      end
    end

    context 'sideloading belongs_to' do
      it 'can sideload' do
        get :index, params: { include: 'state' }
        expect(ids_for('states')).to eq([state.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'state', extra_fields: { states: 'population' } }
        state = json_includes('states')[0]['attributes']
        expect(state['name']).to be_present
        expect(state['abbreviation']).to be_present
        expect(state['population']).to be_present
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'state', fields: { states: 'name' } }
        state = json_includes('states')[0]['attributes']
        expect(state['name']).to be_present
        expect(state).to_not have_key('abbreviation')
        expect(state).to_not have_key('population')
      end

      it 'allows extra fields and sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'state', fields: { states: 'name' }, extra_fields: { states: 'population' } }
        state = json_includes('states')[0]['attributes']
        expect(state).to have_key('name')
        expect(state).to have_key('population')
        expect(state).to_not have_key('abbreviation')
      end
    end

    context 'sideloading has_one' do
      it 'can sideload' do
        get :index, params: { include: 'bio' }
        expect(ids_for('bios')).to eq([bio.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'bio', extra_fields: { bios: 'created_at' } }
        bio = json_includes('bios')[0]['attributes']
        expect(bio['description']).to be_present
        expect(bio['created_at']).to be_present
        expect(bio['picture']).to be_present
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'bio', fields: { bios: 'description' } }
        bio = json_includes('bios')[0]['attributes']
        expect(bio['description']).to be_present
        expect(bio).to_not have_key('created_at')
        expect(bio).to_not have_key('picture')
      end

      it 'allows extra fields and sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'bio', fields: { bios: 'description' }, extra_fields: { bios: 'created_at' } }
        bio = json_includes('bios')[0]['attributes']
        expect(bio).to have_key('description')
        expect(bio).to have_key('created_at')
        expect(bio).to_not have_key('picture')
      end

      # Model/Resource has has_one, but it's just a subset of a has_many
      context 'when multiple records (faux-has_one)' do
        let!(:bio2) { Legacy::Bio.create!(author: author1, picture: 'imgur', description: 'author bio') }

        context 'and there is another level of association' do
          before do
            bio.bio_labels << Legacy::BioLabel.create!
            bio2.bio_labels << Legacy::BioLabel.create!
          end

          it 'still works' do
            get :index, params: { include: 'bio.bio_labels' }
            expect(json_includes('bio_labels').length).to eq(1)
          end
        end
      end
    end

    context 'sideloading many_to_many' do
      it 'can sideload' do
        get :index, params: { include: 'hobbies' }
        expect(ids_for('hobbies')).to eq([hobby1.id, hobby2.id])
      end

      it 'allows sorting of sideloaded resource' do
        get :index, params: { include: 'hobbies', sort: '-hobbies.name' }
        expect(ids_for('hobbies')).to eq([hobby2.id, hobby1.id])
      end

      it 'allows filtering of sideloaded resource' do
        get :index, params: { include: 'hobbies', filter: { hobbies: { id: hobby2.id } } }
        expect(ids_for('hobbies')).to eq([hobby2.id])
      end

      it 'allows extra fields for sideloaded resource' do
        get :index, params: { include: 'hobbies', extra_fields: { hobbies: 'reason' } }
        hobby = json_includes('hobbies')[0]['attributes']
        expect(hobby['name']).to be_present
        expect(hobby['description']).to be_present
        expect(hobby['reason']).to eq('hobby reason')
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'hobbies', fields: { hobbies: 'name' } }
        hobby = json_includes('hobbies')[0]['attributes']
        expect(hobby['name']).to be_present
        expect(hobby).to_not have_key('description')
        expect(hobby).to_not have_key('reason')
      end

      it 'allows extra fields and sparse fieldsets for the sideloaded resource' do
        get :index, params: { include: 'hobbies', fields: { hobbies: 'name' }, extra_fields: { hobbies: 'reason' } }
        hobby = json_includes('hobbies')[0]['attributes']
        expect(hobby).to have_key('name')
        expect(hobby).to have_key('reason')
        expect(hobby).to_not have_key('description')
      end

      it 'allows extra fields and sparse fieldsets for multiple resources' do
        get :index, params: {
          include: 'hobbies,books',
          fields: { hobbies: 'name', books: 'title',  },
          extra_fields: { hobbies: 'reason', books: 'alternate_title' },
        }
        hobby = json_includes('hobbies')[0]['attributes']
        book = json_includes('books')[0]['attributes']
        expect(hobby).to have_key('name')
        expect(hobby).to have_key('reason')
        expect(hobby).to_not have_key('description')
        expect(book).to have_key('title')
        expect(book).to have_key('alternate_title')
        expect(book).to_not have_key('pages')
      end

      it 'does not duplicate results' do
        get :index, params: { include: 'hobbies' }
        author1_relationships = json['data'][0]['relationships']
        author2_relationships = json['data'][1]['relationships']

        author1_hobbies = author1_relationships['hobbies']['data']
        author2_hobbies = author2_relationships['hobbies']['data']

        expect(json_includes('hobbies').size).to eq(2)
        expect(author1_hobbies.size).to eq(2)
        expect(author2_hobbies.size).to eq(1)
      end

      context 'when the table name does not match the association name' do
        before do
          Legacy::AuthorHobby.table_name = :author_hobby
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        after do
          Legacy::AuthorHobby.table_name = :author_hobbies
          Legacy::AuthorResource.class_eval do
            many_to_many :hobbies
          end
        end

        let!(:other_table_hobby1)  { Legacy::Hobby.create!(name: 'Fishing', authors: [author1]) }
        let!(:other_table_hobby2)  { Legacy::Hobby.create!(name: 'Woodworking', authors: [author1, author2]) }

        it 'still works' do
          get :index, params: { include: 'hobbies' }
          expect(ids_for('hobbies'))
            .to eq([other_table_hobby1.id, other_table_hobby2.id])
        end
      end
    end

    context 'sideloading self-referential' do
      it 'works' do
        get :index, params: { include: 'organization.children' }
        includes = json_includes('organizations')
        expect(includes[0]['attributes']['name']).to eq('Org1')
        expect(includes[1]['attributes']['name']).to eq('Org2')
      end
    end

    context 'sideloading the same "type", then adding another sideload' do
      before do
        Legacy::Author.class_eval do
          has_many :other_books, class_name: 'Book'
        end

        Legacy::AuthorResource.class_eval do
          has_many :other_books,
            foreign_key: :author_id,
            resource: Legacy::BookResource
        end
      end

      it 'works' do
        book2.genre = Legacy::Genre.create! name: 'Comedy'
        book2.save!
        get :index, params: {
          filter: { books: { id: book1.id }, other_books: { id: book2.id } },
          include: 'books.genre,other_books.genre'
        }
        expect(json_includes('genres').length).to eq(2)
      end
    end

    context 'sideloading polymorphic belongs_to' do
      it 'allows extra fields for the sideloaded resource' do
        get :index, params: {
          include: 'dwelling',
          extra_fields: { houses: 'house_price', condos: 'condo_price' }
        }
        house = json_includes('houses')[0]['attributes']
        expect(house['name']).to be_present
        expect(house['house_description']).to be_present
        expect(house['house_price']).to eq(1_000_000)
        condo = json_includes('condos')[0]['attributes']
        expect(condo['name']).to be_present
        expect(condo['condo_description']).to be_present
        expect(condo['condo_price']).to eq(500_000)
      end

      it 'allows sparse fieldsets for the sideloaded resource' do
        get :index, params: {
          include: 'dwelling',
          fields: { houses: 'name', condos: 'condo_description' }
        }
        house = json_includes('houses')[0]['attributes']
        expect(house['name']).to be_present
        expect(house).to_not have_key('house_description')
        expect(house).to_not have_key('house_price')
        condo = json_includes('condos')[0]['attributes']
        expect(condo['condo_description']).to be_present
        expect(condo).to_not have_key('name')
        expect(condo).to_not have_key('condo_price')
      end

      it 'allows extra fields and sparse fieldsets for the sideloaded resource' do
        get :index, params: {
          include: 'dwelling',
          fields: { houses: 'name', condos: 'condo_description' },
          extra_fields: { houses: 'house_price', condos: 'condo_price' }
        }
        house = json_includes('houses')[0]['attributes']
        condo = json_includes('condos')[0]['attributes']
        expect(house).to have_key('name')
        expect(house).to have_key('house_price')
        expect(house).to_not have_key('house_description')
        expect(condo).to have_key('condo_description')
        expect(condo).to have_key('condo_price')
        expect(condo).to_not have_key('name')
      end

      # NB: Condo does NOT have a state relationship
      it 'allows additional levels of nesting' do
        get :index, params: { include: 'dwelling.state' }
        expect(json_includes('states').length).to eq(1)
      end
    end
  end
end
