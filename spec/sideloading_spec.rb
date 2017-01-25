require 'spec_helper'

RSpec.describe 'sideloading manually', type: :controller do
  include SideloadHelper
  include_context "sideloading data"

  controller(ApplicationController) do
    jsonapi do
      includes do
        allow_sideload :books, only: [:index] do
          data do |authors|
            Book.where(author_id: authors.map(&:id))
          end

          assign do |authors, books|
            authors.each do |author|
              author.books = books.select { |b| b.author_id == author.id }
            end
          end

          allow_sideload :genre do
            data do |books|
              Genre.where(id: books.map(&:genre_id))
            end

            assign do |books, genres|
              books.each do |book|
                book.genre = genres.find { |g| g.id == book.genre_id }
              end
            end
          end
        end

        allow_sideload :bio do
          data do |authors|
            Bio.where(author_id: authors.map(&:id))
          end

          assign do |authors, bios|
            authors.each do |author|
              author.bio = bios.find { |b| b.author_id == author.id }
            end
          end
        end

        allow_sideload :state do
          data do |authors|
            State.where(id: authors.map(&:state_id))
          end

          assign do |authors, states|
            authors.each do |author|
              author.state = states.find { |s| author.state_id == s.id }
            end
          end
        end

        allow_sideload :hobbies do
          data do |authors|
            Hobby.joins(:author_hobbies).where(author_hobbies: { author_id: authors.map(&:id) })
          end

          assign do |authors, hobbies|
            authors.each do |author|
              author.hobbies = hobbies.select { |h| h.author_hobbies.any? { |ah| ah.author_id == author.id } }
            end
          end
        end

        # TODO - assignment vs render option
        # Maybe just render_as? bc option to render
        allow_sideload :bestsellers, as: :books do
          data do |authors|
            Book.bestseller.where(author_id: authors.map(&:id))
          end

          assign do |authors, bestsellers|
            authors.each do |author|
              author.books = bestsellers.select { |b| b.author_id == author.id }
            end
          end
        end
      end
    end

    def index
      render_jsonapi(Author.all)
    end

    def show
      scope = jsonapi_scope(Author.where(id: params[:id]))
      render_jsonapi(scope.resolve(false))
    end
  end

  include_examples "API sideloading"

  context ':as' do
    it 'renders to alternate key' do
      get :index, params: { include: 'bestsellers' }
      expect(json_included_types).to match_array(%w(books))
    end
  end
end
