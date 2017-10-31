require 'rails_helper'

RSpec.describe Cms::Form, :type => :model do
  let(:request) { double('request') }
  let(:member_id) { rand(1000..9999) }
  let(:cms_key) { instance_double(Symbol) }
  let(:cms) { instance_double(ContentManagementService, get_attribute_as_text: '') }
  let(:subject) { Cms::Form.new(member_id, request, cms_key, cms) }

  describe 'instance methods' do
    describe '`form_page_title`' do
      let(:form_page_title) { instance_double(String) }
      let(:call_method) { subject.form_page_title }

      context 'when the `form_page_title` attr has already been set' do
        before { subject.instance_variable_set(:@form_page_title, form_page_title) }

        it 'returns the attribute' do
          expect(call_method).to eq(form_page_title)
        end
        it 'does not call `get_attribute_as_text` on the cms' do
          expect(subject.cms).not_to receive(:get_attribute_as_text)
          call_method
        end
      end
      context 'when the `form_page_title` attr has not yet been set' do
        it 'calls `get_attribute_as_text` on the cms with the cms_key attribute and `forms-page-name`' do
          expect(subject.cms).to receive(:get_attribute_as_text).with(subject.cms_key, 'forms-page-name')
          call_method
        end
        it 'returns the result of calling `get_attribute_as_text`' do
          allow(subject.cms).to receive(:get_attribute_as_text).and_return(form_page_title)
          expect(call_method).to eq(form_page_title)
        end
        it 'returns the same object if called multiple times' do
          allow(subject.cms).to receive(:get_attribute_as_text).and_return(form_page_title)
          results = call_method
          expect(call_method).to be results
        end
      end
    end
  end
end