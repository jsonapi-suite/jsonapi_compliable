module SideloadHelper
  RSpec.shared_context "sideloading data" do
    let(:state)         { State.new(name: 'maine') }
    let(:genre)         { Genre.new(name: 'horror') }
    let(:book)          { Book.new(title: 'The Shining', genre: genre, sales: 10) }
    let(:hobby)         { Hobby.new(name: 'Music') }
    let(:bio)           { Bio.new(description: 'Horror dude') }
    let(:better_seller) { Book.new(title: 'It', genre: genre, sales: 50) }
    let(:bestseller)    { Book.new(title: 'The Stand', genre: genre, sales: 100) }
    let(:house)         { House.new(name: 'Cozy House') }

    let!(:author) do
      Author.create! \
        first_name: 'Stephen',
        last_name: 'King',
        dwelling: house,
        state: state,
        books: [book, better_seller, bestseller],
        hobbies: [hobby],
        bio: bio
    end
  end

  RSpec.shared_examples "API sideloading" do
    include_context "sideloading data"

    it 'works for has_many' do
      get :index, params: { include: 'books' }
      expect(json_included_types).to match_array(%w(books))
    end

    it 'works for has_one' do
      get :index, params: { include: 'bio' }
      expect(json_included_types).to match_array(%w(bios))
    end

    it 'works for belongs_to' do
      get :index, params: { include: 'state' }
      expect(json_included_types).to match_array(%w(states))
    end

    it 'works for many_to_many' do
      get :index, params: { include: 'hobbies' }
      expect(json_included_types).to match_array(%w(hobbies))
    end

    it 'works for polymorphic relationships' do
      Author.create!(dwelling: Condo.create!(name: 'My Condo'))
      get :index, params: { include: 'dwelling' }
      expect(json_included_types).to match_array(%w(condos houses))
    end

    context 'when no include parameter' do
      it 'renders normally' do
        get :index
        expect(json_included_types).to eq([])
      end
    end

    context 'when nested includes' do
      it 'sideloads all levels of nesting' do
        get :index, params: { include: 'books.genre,state' }
        expect(json_included_types).to match_array(%w(states genres books))
      end
    end

    context 'when the relation is not whitelisted' do
      it 'silently disregards the relation' do
        get :index, params: { include: 'foo' }
        expect(json).to_not have_key('included')
      end
    end
  end
end
