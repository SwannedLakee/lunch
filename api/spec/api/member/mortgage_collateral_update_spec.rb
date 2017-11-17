require 'spec_helper'
require 'net/sftp'

describe MAPI::ServiceApp do
  mortgage_collateral_update_module = MAPI::Services::Member::MortgageCollateralUpdate

  describe 'the mortgage_collateral_update endpoint' do
    let(:call_endpoint) { get "/member/#{member_id}/mortgage_collateral_update" }
    let(:response) { double('response') }
    before { allow(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:mortgage_collateral_update).and_return(response) }
    it 'calls the `mortgage_collateral_update` method with the logger' do
      expect(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:mortgage_collateral_update).with(anything, ActiveRecord::Base.logger, anything)
      call_endpoint
    end
    it 'calls the `mortgage_collateral_update` method with the member id' do
      expect(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:mortgage_collateral_update).with(anything, anything, member_id)
      call_endpoint
    end
    it 'returns the results of the method call as JSON' do
      expect(response).to receive(:to_json)
      call_endpoint
    end
    it 'returns a 200 if there are no errors' do
      call_endpoint
      expect(last_response.status).to eq(200)
    end
    describe 'error states' do
      let(:error) { Savon::Error }
      before { allow(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:mortgage_collateral_update).and_raise(error) }
      it 'logs any Savon::Error that arises' do
        expect(ActiveRecord::Base.logger).to receive(:error).with(error)
        call_endpoint
      end
      it 'returns a 503 if there is a Savon::Error' do
        call_endpoint
        expect(last_response.status).to eq(503)
      end
    end
  end

  describe 'the mortgage_collateral_update method' do
    string_fields  = %w(mcu_type pledge_type transaction_number).map(&:upcase)
    integer_fields = %w(accepted_count depledged_count pledged_count rejected_count renumbered_count total_count updated_count).map(&:upcase)
    float_fields   = %w(accepted_unpaid depledged_unpaid pledged_unpaid rejected_unpaid renumbered_unpaid total_unpaid updated_unpaid
                        accepted_original depledged_original pledged_original rejected_original renumbered_original total_original updated_original).map(&:upcase)
    let(:date_processed_string) { double('date_processed_string')}
    let(:date_doubles) {  { 'DATE_PROCESSED' => double('date_processed', to_s: date_processed_string)} }
    let(:string_doubles)  { Hash[(  string_fields.map { |key| [key, double(key, to_s: nil)] } )].with_indifferent_access }
    let(:integer_doubles) { Hash[( integer_fields.map { |key| [key, double(key, to_i: nil)] } )].with_indifferent_access }
    let(:float_doubles)   { Hash[(   float_fields.map { |key| [key, double(key, to_f: nil)] } )].with_indifferent_access }
    let(:mcu_data) { float_doubles.merge(integer_doubles).merge(string_doubles).merge(date_doubles).with_indifferent_access }
    let(:logger) { double('logger') }

    before { allow(Date).to receive(:parse).with(date_processed_string) }

    [:development, :test, :production].each do |env|
      describe "in the #{env} environment" do
        let(:call_method) { MAPI::Services::Member::MortgageCollateralUpdate.mortgage_collateral_update(env, logger, member_id) }

        if env == :production
          before { allow(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:fetch_hash).and_return(mcu_data) }
          
          # tests specific to production environment
          it 'calls the shared utility function `fetch_hash` with the logger as an argument' do
            expect(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:fetch_hash).with(logger, anything)
            call_method
          end
          it 'calls the shared utility function `fetch_hash` with the proper sql query' do
            sql_query = MAPI::Services::Member::MortgageCollateralUpdate::Private.mcu_sql(member_id)
            expect(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:fetch_hash).with(anything, sql_query)
            call_method
          end
        else
          before { allow(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:fake_hash).with('mortgage_collateral_update').and_return(mcu_data) }

          # test specific to development and test environments
          it 'calls the `fake_hash` class method with `mortgage_collateral_update` to fetch the fake data' do
            expect(MAPI::Services::Member::MortgageCollateralUpdate).to receive(:fake_hash).with('mortgage_collateral_update')
            call_method
          end
        end

        # tests common to all environments
        it 'sets the `date_processed` field to the value of the returned data' do
          expect(call_method[:date_processed]).to eq(Date.parse(mcu_data['DATE_PROCESSED'].to_s))
        end
        string_fields.each do |field|
          it "sets the `#{field.downcase}` field with the proper string" do
            allow(mcu_data[field]).to receive(:to_s).and_return(mcu_data[field])
            expect(call_method[field.downcase]).to eq(mcu_data[field])
          end
        end
        integer_fields.each do |field|
          it "sets the `#{field.downcase}` field with the proper integer" do
            allow(mcu_data[field]).to receive(:to_i).and_return(mcu_data[field])
            expect(call_method[field.downcase]).to eq(mcu_data[field])
          end
        end
        float_fields.each do |field|
          it "sets the `#{field.downcase}` field with the proper float" do
            allow(mcu_data[field]).to receive(:to_f).and_return(mcu_data[field])
            expect(call_method[field.downcase]).to eq(mcu_data[field])
          end
        end
      end
    end
  end

  describe 'MCU methods' do
    let(:app) { instance_double(MAPI::ServiceApp, logger: double('logger', error: nil)) }
    describe 'the `mcu_transaction_id` method' do
      let(:call_method) { mortgage_collateral_update_module.mcu_transaction_id(app, member_id) }
      describe 'when `should_fake?` returns `true`' do
        let(:random) { rand(9999..99999) }
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
        end
        it 'calls for a random id' do
          expect(mortgage_collateral_update_module).to receive(:rand).with(9999..99999)
          call_method
        end
        it 'returns the random value' do
          expect(mortgage_collateral_update_module).to receive(:rand).and_return(random)
          expect(call_method).to eq({ transaction_id: random })
        end
      end
      describe 'when `should_fake?` returns `false`' do
        let(:response) { instance_double(Hash, :[] => nil )}
        let(:transaction_id) { double('transaction_id') }
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
          allow(mortgage_collateral_update_module).to receive(:get_message).and_return(response)
        end
        it 'calls `get_message` with the appropriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:get_message).with(app, 'GET_TRANSACTION_ID')
          call_method
        end
        it 'returns the result of `get_message`' do
          allow(response).to receive(:[]).with(:body).and_return(transaction_id)
          expect(call_method).to eq({ transaction_id: transaction_id })
        end
      end
    end

    describe 'the `mcu_member_info` method' do
      let(:call_method) { mortgage_collateral_update_module.mcu_member_info(app, member_id) }
      let(:member_info) { double('member info') }
      let(:member_info_for_one_member) { double('member info for one member') }
      before do
        allow(member_info).to receive(:[]).and_return(member_info_for_one_member)
      end
      describe 'when `should_fake?` returns `true`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
          allow(mortgage_collateral_update_module).to receive(:fake_hash).and_return(member_info)
        end        
        it 'loads the fake' do
          expect(mortgage_collateral_update_module).to receive(:fake_hash).with('member_mcu_member_info')
          call_method
        end
        describe 'in the fake world' do
          before do
            allow(mortgage_collateral_update_module).to receive(:fake_hash).and_return(member_info)
          end      
          it 'gets the fake data for the given `member_id`' do
            expect(member_info).to receive(:[]).with(member_id.to_s)
            call_method
          end
          it 'returns the fake data' do
            expect(call_method).to eq(member_info_for_one_member)            
          end
        end
      end
      describe 'when `should_fake?` returns `false`' do
        let(:response) { instance_double(Hash, :[] => nil) }
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
          allow(mortgage_collateral_update_module).to receive(:get_message).and_return(response)
          allow(response).to receive(:[]).with(:body).and_return(member_info)
        end   
        it 'calls `get_message` with the apppriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:get_message).with(app, 'GET_MEMBER_INFO')
          call_method
        end
        it 'gets the member info for the current member' do
          expect(member_info).to receive(:[]).with(member_id.to_s)
          call_method          
        end
        describe 'in the real world' do
          it 'returns the real data' do
            expect(call_method).to eq(member_info_for_one_member)
          end
        end
      end
    end
    describe 'the `mcu_server_info` method' do
      let(:call_method) { mortgage_collateral_update_module.mcu_server_info(app) }
      let(:server_info) { { headers: { "svcAccountUsername"=>"username", 
                            "svcAccountPassword"=>"password", 
                            "archiveDir"=>"path", 
                            "hostname"=>"host" } } }
      describe 'when `should_fake?` returns `true`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
        end
        it 'loads the fake' do
          expect(mortgage_collateral_update_module).to receive(:fake_hash).with('member_mcu_server_info')
          call_method
        end
        describe 'in the fake world' do
          before do
            allow(mortgage_collateral_update_module).to receive(:fake).and_return(server_info[:headers])
          end
          it 'returns the fake data' do
            expect(call_method).to eq(server_info[:headers])
          end
        end
      end
      describe 'when `should_fake?` returns `false`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
          allow(mortgage_collateral_update_module).to receive(:get_message).and_return(server_info)
        end
        it 'calls `get_message` with the apppriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:get_message).with(app, 'GetServerInfo', nil, {})
          call_method
        end
        describe 'in the real world' do
          it 'return the real data' do
            expect(call_method).to eq(server_info[:headers])
          end
        end
      end
    end
    describe 'the `mcu_member_status` method' do
      let(:call_method) { mortgage_collateral_update_module.mcu_member_status(app, member_id) }
      let(:member_status) { [{ "transactionId" => 210585, "uploadType" => "COMPLETE", "authorizedBy" =>"IX_TEST",
                               "authorizedOn" =>"2017-09-20", "status" =>"ERROR", "numberOfLoans" => 0, "numberOfErrors" => 0,
                               "canCancel" => false, "canView"=>false}] }
      let(:mcu_type) { SecureRandom.hex }
      let(:member_status_upload) { ["uploadType" => mcu_type] }
      let(:member_status_result) { ["mcuType" => mcu_type] }
      let(:response) { instance_double(Hash, :[] => member_status) }
      describe 'when `should_fake?` returns `true`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
        end
        it 'loads the fake' do
          expect(mortgage_collateral_update_module).to receive(:fake).with('member_mcu_status')
          call_method
        end
        describe 'in the fake world' do
          before do
            allow(mortgage_collateral_update_module).to receive(:fake).and_return(member_status)
          end
          it 'returns the fake data' do
            expect(call_method).to eq(member_status)
          end
        end
      end
      describe 'when `should_fake?` returns `false`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
          allow(mortgage_collateral_update_module).to receive(:get_message).and_return(response)
        end
        it 'calls `get_message` with the apppriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:get_message).with(app, 'GET_MEMBER_TRANSACTIONS', member_id, {partnerId: member_id})
          call_method
        end
        describe 'in the real world' do
          it 'return the real data' do
            expect(call_method).to eq(member_status)
          end
        end
      end
      it 'converts `uploadType` to `mcu_type` and returns the result in the fake world' do
        allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
        allow(mortgage_collateral_update_module).to receive(:fake).and_return(member_status_upload)
        expect(call_method).to eq(member_status_result)
      end
      it 'converts `uploadType` to `mcu_type` and returns the result in the real world' do
        allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
        allow(mortgage_collateral_update_module).to receive(:get_message).and_return(response)
        allow(response).to receive(:[]).and_return(member_status_upload) 
        expect(call_method).to eq(member_status_result)
      end
    end
    describe 'the `mcu_upload_file` method' do
      let(:transaction_id) { SecureRandom.hex }
      let(:file_type) { SecureRandom.hex }
      let(:pledge_type) { SecureRandom.hex }
      let(:remote_path) { "#{SecureRandom.hex}.#{SecureRandom.hex}" }
      let(:archive_dir) { remote_path[0..12] }
      let(:username) { SecureRandom.hex }
      let(:call_method) { mortgage_collateral_update_module.mcu_upload_file(app, 
                                                                            member_id,
                                                                            transaction_id,
                                                                            file_type,
                                                                            pledge_type,
                                                                            username,
                                                                            remote_path,
                                                                            archive_dir) }
      describe 'when `should_fake?` returns `true`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(true)
        end
        it 'returns a success message' do
          expect(call_method).to eq({ success: true, message: '' })
        end
      end
      describe 'when `should_fake?` returns `false`' do
        before do
          allow(mortgage_collateral_update_module).to receive(:should_fake?).and_return(false)
          allow(mortgage_collateral_update_module).to receive(:post_message).and_return(nil)
          allow(app.logger).to receive(:error)
        end
        it 'calls `INITIATE_FILE_SUBMISSION` with the appropriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:post_message).with( app, 
                                                                                    'INITIATE_FILE_SUBMISSION', 
                                                                                    { 'memberId': member_id,
                                                                                      'fileTypeId': file_type.split('_')[0],
                                                                                      'transactionId': transaction_id,
                                                                                      'fileName': remote_path,
                                                                                      'extension': File.extname(remote_path)[1..-1],
                                                                                      'pledgeType': pledge_type,
                                                                                      'submittedBy': username })
          call_method
        end
        it 'posts a message without a command with the appropriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:post_message).with( app, 
                                                                                    nil,
                                                                                    { 'FHLBId': member_id,
                                                                                      'TRANS_NUM': transaction_id,
                                                                                      'MCUType': file_type.split('_')[1],
                                                                                      'DataDate': Time.zone.now.strftime('%d-%^b-%Y'),
                                                                                      'FileName': remote_path.gsub(archive_dir, ''),
                                                                                      'Extension': File.extname(remote_path)[1..-1],
                                                                                      'PledgeType': pledge_type })
          call_method
        end
        it 'calls `UPDATE_FILE_STATUS` with the apprpriate arguments' do
          expect(mortgage_collateral_update_module).to receive(:post_message).with( app,
                                                                                    'UPDATE_FILE_STATUS',
                                                                                    { 'transactionId': transaction_id,
                                                                                      'status': 'Authorized' })
          call_method
        end
        it 'returns a success message' do
          expect(call_method).to eq({ success: true, message: '' })
        end
      end
    end
  end
end