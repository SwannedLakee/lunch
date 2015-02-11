require 'rails_helper'

RSpec.describe CorporateCommunicationsController, :type => :controller do
  login_user

  describe 'before_filter methods' do
    it 'should set @sidebar_options as an array of options with a label and a value' do
      get :category, category: 'all'
      expect(assigns(:sidebar_options)).to be_kind_of(Array)
      assigns(:sidebar_options).each do |option|
        expect(option.first).to be_kind_of(String)
        expect(option.last).to be_kind_of(String)
      end
    end
    CorporateCommunication::VALID_CATEGORIES.each do |category|
      it "should set @filter to #{category} if that is passed in as an argument" do
        get :category, category: category
        expect(assigns(:filter)).to eq(category)
      end
    end
    it 'should raise an error if the passed category argument is not valid' do
      expect{get :category, category: 'asdffsd'}.to raise_error
    end
    it 'should raise an error if nothing is passed as a category argument' do
      expect{get :category}.to raise_error
    end
  end

  describe 'GET category' do
    it_behaves_like 'a user required action', :get, :category, category: 'all'
    let(:message_service_instance) { double('MessageServiceInstance') }
    let(:corporate_communications) { double('Array of Messages') }
    it 'should render the category view' do
      get :category, category: 'all'
      expect(response.body).to render_template('category')
    end
    it 'should pass @filter to MessageService#corporate_communications as an argument' do
      expect(message_service_instance).to receive(:corporate_communications).with('all')
      expect(MessageService).to receive(:new).and_return(message_service_instance)
      get :category, category: 'all'
    end
    it 'should set @messages to the value returned by MessageService#corporate_communications' do
      expect(message_service_instance).to receive(:corporate_communications).and_return(corporate_communications)
      expect(MessageService).to receive(:new).and_return(message_service_instance)
      get :category, category: 'all'
      expect(assigns[:messages]).to eq(corporate_communications)
    end
  end

  describe 'GET show' do
    it_behaves_like 'a user required action', :get, :category, category: 'all', id: ::FactoryGirl.build(:corporate_communication)
    let(:corporate_communication) { ::FactoryGirl.create(:corporate_communication, category: 'accounting') }
    it 'sets @message to the appropriate CorporateCommunication record if `all` is given as the category argument' do
      expect(CorporateCommunication).to receive(:find).with(corporate_communication.id.to_s).and_call_original
      get :show, category: 'all', id: corporate_communication
      expect(assigns[:message]).to eq(corporate_communication)
    end
    it 'sets @message to the appropriate CorporateCommunication record given the proper category' do
      expect(CorporateCommunication).to receive(:find_by!).with({:id => corporate_communication.id.to_s, :category => 'accounting'}).and_call_original
      get :show, category: 'accounting', id: corporate_communication
      expect(assigns[:message]).to eq(corporate_communication)
    end
    describe 'setting the @prior_message and @next_message instance variables' do
      before do
        @message_1 = ::FactoryGirl.create(:corporate_communication)
        @message_2 = ::FactoryGirl.create(:corporate_communication)
        @message_3 = ::FactoryGirl.create(:corporate_communication)
      end
      it 'sets @prior_message to the message just before the currently selected message in a given category' do
        get :show, category: 'all', id: @message_2.id
        expect(assigns[:prior_message]).to eq(@message_1)
      end
      it 'does not set @prior_message if the currently selected message is the first in a given category' do
        get :show, category: 'all', id: @message_1.id
        expect(assigns[:prior_message]).to be_nil
      end
      it 'sets @next_message to the message just after the currently selected message in a given category' do
        get :show, category: 'all', id: @message_2.id
        expect(assigns[:next_message]).to eq(@message_3)
      end
      it 'does not set @next_message if the currently selected message is the last in a given category' do
        get :show, category: 'all', id: @message_3.id
        expect(assigns[:next_message]).to be_nil
      end
    end
  end

end