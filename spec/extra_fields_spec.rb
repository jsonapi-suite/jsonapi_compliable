require 'spec_helper'

RSpec.describe 'extra_fields' do
  include JsonHelpers
  include_context 'resource testing'
  let(:resource) { Class.new(PORO::EmployeeResource).new }
  let(:base_scope) { { type: :employees } }

  let!(:employee) { PORO::Employee.create }

  def attributes
    json['data'][0]['attributes']
  end

  it 'does not include extra fields when not requested' do
    render
    expect(attributes.keys).to match_array(%w(first_name last_name age))
  end

  it 'includes the extra fields in the response when requested' do
    params[:extra_fields] = { employees: 'stack_ranking' }
    render
    expect(attributes.keys)
      .to match_array(%w(first_name last_name age stack_ranking))
  end

  context 'when altering scope based on extra attrs' do
    before do
      resource.class.class_eval do
        extra_field :net_worth do |scope|
          scope[:foo] = 'bar'
          scope
        end
      end
    end

    it 'modifies the scope' do
      params[:extra_fields] = { employees: 'net_worth' }
      expect(PORO::DB).to receive(:all).with(hash_including(foo: 'bar'))
      render
    end
  end

  context 'when acessing runtime context' do
    before do
      params[:extra_fields] = { employees: 'runtime_id' }
    end

    it 'works' do
      ctx = double(runtime_id: 789).as_null_object
      resource.with_context ctx do
        render
        expect(attributes['runtime_id']).to eq(789)
      end
    end
  end

  context 'when extra field is guarded' do
    before do
      params[:extra_fields] = { employees: 'admin_stack_ranking' }
    end

    context 'and the guard passes' do
      it 'renders the field' do
        ctx = double(current_user: 'admin').as_null_object
        resource.with_context ctx do
          render
          expect(attributes.keys).to include('admin_stack_ranking')
        end
      end
    end

    context 'and the guard fails' do
      it 'does not render the field' do
        ctx = double(current_user: 'foo').as_null_object
        resource.with_context ctx do
          render
          expect(attributes.keys).to_not include('admin_stack_ranking')
        end
      end
    end
  end
end
