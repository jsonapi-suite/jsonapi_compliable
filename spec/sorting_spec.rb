require 'spec_helper'

RSpec.describe 'sorting', type: :controller do
  controller(ApplicationController) do
    jsonapi {}

    def index
      render_jsonapi(Author.all)
    end
  end

  before do
    Author.create!(first_name: 'Stephen')
    Author.create!(first_name: 'Philip')
  end

  it 'defaults sort to controller default_sort' do
    expect(controller).to receive(:default_sort) { 'id' }
    get :index
    expect(json_ids(true)).to eq(Author.pluck(:id))
    expect(controller).to receive(:default_sort) { '-id' }
    get :index
    expect(json_ids(true)).to eq(Author.pluck(:id).reverse)
  end

  context 'when passing sort param' do
    subject do
      get :index, params: { sort: sort_param }
      json_items.map { |n| n['first_name'] }
    end

    context 'asc' do
      let(:sort_param) { 'first_name' }

      it { is_expected.to eq(%w(Philip Stephen)) }
    end

    context 'desc' do
      let(:sort_param) { '-first_name' }

      it { is_expected.to eq(%w(Stephen Philip)) }
    end

    context 'when given a custom sort function' do
      let(:sort_param) { 'first_name' }

      before do
        controller.class_eval do
          jsonapi do
            sort do |scope, att, dir|
              raise("custom sort #{att} #{dir}")
            end
          end
        end
      end

      it 'uses the custom sort function' do
        expect { subject }.to raise_error('custom sort first_name asc')
      end
    end
  end
end
