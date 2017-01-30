require 'spec_helper'

RSpec.describe JsonapiCompliable::Query do
  describe '.parse' do
    let(:params) do
      {
        filter: {
          id: 1,
          books: {
            title: 'foo'
          }
        },
        sort: 'name,-id,-books.title',
        page: {
          number: 2,
          size: 10,
          books: { number: 1, size: 3 }
        }
      }
    end

    let(:dsl) do
      dsl = JsonapiCompliable::DSL.new
      dsl.includes do
        allow_sideload :books do
          allow_sideload :genre do
          end
        end
      end
      dsl
    end

    let(:controller) do
      double(params: params, _jsonapi_compliable: dsl)
    end

    subject { described_class.new(controller).to_hash }

    it 'should assign filter correctly for default type' do
      expect(subject[:default][:filter]).to eq({
        id: 1
      })
    end

    it 'should assign filter correctly for associations' do
      expect(subject[:books][:filter]).to eq({
        title: 'foo'
      })
    end

    it 'should assign sort correctly for default type' do
      expect(subject[:default][:sort])
        .to eq([{ name: :asc }, { id: :desc }])
    end

    it 'should assign sort correctly for associations' do
      expect(subject[:books][:sort]).to eq([{ title: :desc }])
    end

    it 'should assign pagination correctly for default type' do
      expect(subject[:default][:page]).to eq(size: 10, number: 2)
    end
  end
end
