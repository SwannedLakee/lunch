require 'rails_helper'
include CustomFormattingHelper

RSpec.describe DashboardController, :type => :controller do
  login_user
  before do
    session['member_id'] = 750
  end

  let(:borrowing_capacity_summary) do
    {
      total_borrowing_capacity: rand(1000000..9999999),
      net_plus_securities_capacity: rand(1000000..9999999),
      standard_excess_capacity: rand(1000000..9999999),
      sbc: {
        collateral: {
          agency: {
            remaining_borrowing_capacity: rand(1000000..9999999),
            total_borrowing_capacity: rand(1000000..9999999)
          },
          aaa: {
            remaining_borrowing_capacity: rand(1000000..9999999),
            total_borrowing_capacity: rand(1000000..9999999)
          },
          aa: {
            remaining_borrowing_capacity: rand(1000000..9999999),
            total_borrowing_capacity: rand(1000000..9999999)
          }
        }
      }
    }
  end

  it { should use_around_filter(:skip_timeout_reset) }

  {AASM::InvalidTransition => [AdvanceRequest.new(7, 'foo'), 'executed', :default], AASM::UnknownStateMachineError => ['message'], AASM::UndefinedState => ['foo'], AASM::NoDirectAssignmentError => ['message']}.each do |exception, args|
    describe "`rescue_from` #{exception}" do
      let(:make_request) { get :index }
      before do
        allow(subject).to receive(:index).and_raise(exception.new(*args))
      end

      it 'logs at the `info` log level' do
        allow(subject.logger).to receive(:info).and_call_original
        expect(subject.logger).to receive(:info).with(no_args) do |*args, &block|
          expect(block.call).to match(/Exception: /i)
        end.exactly(:once)
        make_request rescue exception
      end
      it 'puts the advance_request as JSON in the log' do
        expect(subject.send(:advance_request)).to receive(:to_json).and_call_original
        make_request rescue exception
      end
      it 'reraises the error' do
        expect{make_request}.to raise_error(exception)
      end

    end
  end

  describe "GET index", :vcr do
    let(:member_id) {750}
    let(:empty_financing_availability_gauge) {{total: {amount: 0, display_percentage: 100, percentage: 0}}}
    let(:profile) { double('profile') }
    let(:service) { double('a service object', profile: profile) }
    let(:make_request) { get :index }
    let(:etransact_status) { double('some status') }
    let(:etransact_service) { double('etransact service', etransact_status: etransact_status) }
    let(:borrowing_capacity_hash) do
      {
        total_borrowing_capacity: double('total_borrowing_capacity'),
        net_plus_securities_capacity: double('net_plus_securities_capacity'),
        sbc: {
          collateral: {
            aa: {total_borrowing_capacity: double('aa total_borrowing_capacity')},
            aaa: {total_borrowing_capacity: double('aaa total_borrowing_capacity')},
            agency: {total_borrowing_capacity: double('agency total_borrowing_capacity')}
          }
        }
      }
    end
    before do
      allow(Time).to receive_message_chain(:zone, :now, :to_date).and_return(Date.new(2015, 6, 24))
      allow_any_instance_of(MembersService).to receive(:member_contacts)
      allow(MessageService).to receive(:new).and_return(double('service instance', todays_quick_advance_message: nil))
      allow(QuickReportSet).to receive_message_chain(:for_member, :latest_with_reports).and_return(nil)
    end

    it_behaves_like 'a user required action', :get, :index
    it_behaves_like 'a controller action with quick advance messaging', :index
    it "renders the index view" do
      get :index
      expect(response.body).to render_template("index")
    end
    it 'populates the deferred jobs view parameters' do
      expect(subject).to receive(:populate_deferred_jobs_view_parameters).with(DashboardController::DEFERRED_JOBS)
      get :index
    end
    it 'checks the profile for disabled endpoints' do
      allow(MemberBalanceService).to receive(:new).and_return(service)
      expect(subject).to receive(:sanitize_profile_if_endpoints_disabled).with(profile).and_return({})
      get :index
    end
    it "assigns @market_overview" do
      get :index
      expect(assigns[:market_overview]).to be_present
      expect(assigns[:market_overview][0]).to be_present
      expect(assigns[:market_overview][0][:name]).to be_present
      expect(assigns[:market_overview][0][:data]).to be_present
    end
    it 'calls `calculate_gauge_percentages` for @financing_availability_gauge'  do
      expect(subject).to receive(:calculate_gauge_percentages).once
      get :index
    end
    it 'assigns @current_overnight_vrc' do
      get :index
      expect(assigns[:current_overnight_vrc]).to be_kind_of(Float)
    end
    describe 'when the `add-advance` feature is enabled' do
      before do
        allow(controller).to receive(:feature_enabled?).and_call_original
        allow(controller).to receive(:feature_enabled?).with('add-advance').and_return(true)
      end
      it 'assigns @etransact_status from the value returned by the `EtransactAdvancesService#etransact_status` instance method' do
        allow(EtransactAdvancesService).to receive(:new).and_return(etransact_service)
        get :index
        expect(assigns[:etransact_status]).to eq(etransact_status)
      end
    end
    describe 'when the `add-advance` feature is disabled' do
      before do
        allow(controller).to receive(:feature_enabled?).and_call_original
        allow(controller).to receive(:feature_enabled?).with('add-advance').and_return(false)
      end
      it 'should assign @quick_advance_status' do
        get :index
        expect(assigns[:quick_advance_status]).to be_present
      end
      it 'should assign @quick_advance_status to `:open` if the desk is enabled and we have terms' do
        get :index
        expect(assigns[:quick_advance_status]).to eq(:open)
      end
      it 'should assign @quick_advance_status to `:no_terms` if the desk is enabled and we have no terms' do
        allow_any_instance_of(EtransactAdvancesService).to receive(:has_terms?).and_return(false)
        get :index
        expect(assigns[:quick_advance_status]).to eq(:no_terms)
      end
      it 'should assign @quick_advance_status to `:open` if the desk is disabled' do
        allow_any_instance_of(EtransactAdvancesService).to receive(:etransact_active?).and_return(false)
        get :index
        expect(assigns[:quick_advance_status]).to eq(:closed)
      end
      it 'sets @advance_terms' do
        get :index
        expect(assigns[:advance_terms]).to eq(AdvanceRequest::ADVANCE_TERMS)
      end
      it 'sets @advance_types' do
        get :index
        expect(assigns[:advance_types]).to eq(AdvanceRequest::ADVANCE_TYPES)
      end
    end
    it 'should assign @financing_availability_gauge' do
      get :index
      expect(assigns[:financing_availability_gauge]).to be_kind_of(Hash)
      expect(assigns[:financing_availability_gauge][:used]).to be_kind_of(Hash)
      expect(assigns[:financing_availability_gauge][:used][:amount]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:used][:percentage]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:used][:display_percentage]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:unused][:amount]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:unused][:percentage]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:unused][:display_percentage]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:uncollateralized][:amount]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:uncollateralized][:percentage]).to be_kind_of(Numeric)
      expect(assigns[:financing_availability_gauge][:uncollateralized][:display_percentage]).to be_kind_of(Numeric)
    end
    describe 'the @contacts instance variable' do
      let(:contacts) { double('some contact') }
      let(:cam_username) { 'cam' }
      let(:rm_username) { 'rm' }
      let(:uppercase_username) { 'ALLCAPSNAME' }
      before do
        allow_any_instance_of(MembersService).to receive(:member_contacts).and_return(contacts)
        allow(contacts).to receive(:[]).with(:cam).and_return({username: cam_username})
        allow(contacts).to receive(:[]).with(:rm).and_return({username: rm_username})
        allow(subject).to receive(:find_asset)
        allow(Rails.cache).to receive(:fetch).with(any_args).and_yield.and_return(contacts)
      end
      it 'is the result of the `members_service.member_contacts` method' do
        get :index
        expect(assigns[:contacts]).to eq(contacts)
      end
      it 'contains an `image_url` for the cam' do
        allow(subject).to receive(:find_asset).with("#{cam_username}.jpg").and_return(true)
        get :index
        expect(assigns[:contacts][:cam][:image_url]).to eq("#{cam_username}.jpg")
      end
      it 'contains an `image_url` for the rm' do
        allow(subject).to receive(:find_asset).with("#{rm_username}.jpg").and_return(true)
        get :index
        expect(assigns[:contacts][:rm][:image_url]).to eq("#{rm_username}.jpg")
      end
      it 'contains an `image_url` that is the downcased version of the username for the rm' do
        allow(contacts).to receive(:[]).with(:rm).and_return({username: uppercase_username})
        allow(subject).to receive(:find_asset).with("#{uppercase_username.downcase}.jpg").and_return(true)
        get :index
        expect(assigns[:contacts][:rm][:image_url]).to eq("#{uppercase_username.downcase}.jpg")
      end
      it 'contains an `image_url` that is the downcased version of the username for the cam' do
        allow(contacts).to receive(:[]).with(:cam).and_return({username: uppercase_username})
        allow(subject).to receive(:find_asset).with("#{uppercase_username.downcase}.jpg").and_return(true)
        get :index
        expect(assigns[:contacts][:cam][:image_url]).to eq("#{uppercase_username.downcase}.jpg")
      end
      it 'assigns the default `image_url` if the image asset does not exist for the contact' do
        allow(subject).to receive(:find_asset).and_return(false)
        get :index
        expect(assigns[:contacts][:rm][:image_url]).to eq('placeholder-usericon.svg')
        expect(assigns[:contacts][:cam][:image_url]).to eq('placeholder-usericon.svg')
      end
      it 'returns {} if nil is returned from the service object' do
        allow_any_instance_of(MembersService).to receive(:member_contacts).and_return(nil)
        allow(Rails.cache).to receive(:fetch).with(any_args).and_yield.and_return({})
        get :index
        expect(assigns[:contacts]).to eq({})
      end
    end
    describe "RateService failures" do
      let(:RatesService) {class_double(RatesService)}
      let(:rate_service_instance) {RatesService.new(double('request', uuid: '12345'))}
      before do
        expect(RatesService).to receive(:new).and_return(rate_service_instance)
      end
      it 'should assign @current_overnight_vrc as nil if the rate could not be retrieved' do
        expect(rate_service_instance).to receive(:current_overnight_vrc).and_return(nil)
        get :index
        expect(assigns[:current_overnight_vrc]).to eq(nil)
      end
      it 'should assign @market_overview rate data as nil if the rates could not be retrieved' do
        expect(rate_service_instance).to receive(:overnight_vrc).and_return(nil)
        get :index
        expect(assigns[:market_overview][0][:data]).to eq(nil)
      end
    end
    describe "MemberBalanceService failures" do
      it 'should assign @financing_availability_gauge to a zeroed out gauge if there is no value for `financing_availability` in the profile' do
        allow_any_instance_of(MemberBalanceService).to receive(:profile).and_return({credit_outstanding: {}})
        get :index
        expect(assigns[:financing_availability_gauge]).to eq(empty_financing_availability_gauge)
      end
      it 'should respond with a 200 even if MemberBalanceService#profile returns nil' do
        allow_any_instance_of(MemberBalanceService).to receive(:profile).and_return(nil)
        get :index
        expect(response).to be_success
      end
    end
    describe "Member Service flags" do
      before do
        allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, anything).and_return(false)
      end
      it 'should set @financing_availability_gauge to be zeroed out if the report is disabled' do
        allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::FINANCING_AVAILABLE_DATA]).and_return(true)
        get :index
        expect(assigns[:financing_availability_gauge]).to eq(empty_financing_availability_gauge)
      end
      it 'should set @borrowing_capacity to be nil if the report is disabled' do
        allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::COLLATERAL_REPORT_DATA]).and_return(true)
        get :index
        expect(assigns[:borrowing_capacity]).to eq(nil)
      end
    end

    describe 'Quick Reports module' do
      let(:member) { Member.new(member_id) }
      let(:report_list) { described_class::QUICK_REPORT_MAPPING.keys.sample(2) }
      let(:quick_report_set) { double(QuickReportSet, member: member, period: '2015-03') }
      let(:quick_reports) { double(ActiveRecord::Relation, completed: []) }
      before do
        allow(QuickReportSet).to receive(:for_member).with(member_id).and_return(double(ActiveRecord::Relation, latest_with_reports: quick_report_set))
        allow(member).to receive(:quick_report_list).and_return(report_list)
        allow(quick_report_set).to receive(:reports_named).with(report_list.collect(&:to_s)).and_return(quick_reports)
      end
      it 'assigns @quick_reports_period' do
        make_request
        expect(assigns[:quick_reports_period]).to eq(Date.new(2015, 3, 1))
      end
      it 'assigns @quick_reports' do
        make_request
        expect(assigns[:quick_reports].length).to be(report_list.length)
        report_list.each do |report|
          expect(assigns[:quick_reports][report]).to include(title: described_class::QUICK_REPORT_MAPPING[report])
        end
      end
      context 'the feature is flipped off' do
        before do
          allow(controller).to receive(:feature_enabled?).and_call_original
          allow(controller).to receive(:feature_enabled?).with('quick-reports').and_return(false)
        end
        it 'does not assign @quick_reports' do
          make_request
          expect(assigns[:quick_reports]).to_not be_present
        end
        it 'does not assign @quick_reports_period' do
          make_request
          expect(assigns[:quick_reports_period]).to_not be_present
        end
      end
      context do
        let(:reports) { [] }
        let(:report_urls) { {} }
        before do
          report_list.each do |report|
            url = double("A URL for #{report}")
            quick_report = QuickReport.new(report_name: report)
            allow(controller).to receive(:reports_quick_download_path).with(quick_report).and_return(url)
            report_urls[report] = url
            reports << quick_report
          end
          allow(quick_reports).to receive(:completed).and_return(reports)
        end
        it 'adds a URL to @quick_reports for each report has been generated' do
          make_request
          reports.each do |report|
            expect(assigns[:quick_reports][report.report_name][:url]).to be(report_urls[report.report_name])
          end
        end
        it 'does not include download links for reports that have not been generated successfully' do
         uncompleted_reports = [:foo, :bar]
         new_report_list = report_list + uncompleted_reports
         allow(member).to receive(:quick_report_list).and_return(new_report_list)
         allow(quick_report_set).to receive(:reports_named).with(new_report_list.collect(&:to_s)).and_return(quick_reports)
         make_request
         uncompleted_reports.each do |report|
           expect(assigns[:quick_reports][report][:url]).to be_nil
         end
        end
        it 'does not include reports that are not in the members report list' do
          make_request
          expect(assigns[:quick_reports].keys - report_list).to eq([])
        end
      end
    end
  end

  describe "GET quick_advance_rates", :vcr do
    allow_policy :advances, :show?
    let(:rate_data) { {some: 'data'} }
    let(:RatesService) {class_double(RatesService)}
    let(:rate_service_instance) {double("rate service instance", quick_advance_rates: nil)}
    let(:advance_request) { double(AdvanceRequest, rates: rate_data, errors: [], id: SecureRandom.uuid, :allow_grace_period= => nil) }
    let(:make_request) { get :quick_advance_rates }

    before do
      allow(subject).to receive(:advance_request).and_return(advance_request)
    end

    it_behaves_like 'a user required action', :get, :quick_advance_rates
    it_behaves_like 'an authorization required method', :get, :quick_advance_rates, :advances, :show?
    it 'gets the rates from the advance request' do
      expect(subject).to receive(:advance_request).and_return(advance_request)
      expect(advance_request).to receive(:rates).and_return(rate_data)
      make_request
    end
    it 'render its view' do
      make_request
      expect(response.body).to render_template('dashboard/quick_advance_rates')
    end
    it 'includes the html in its response' do
      make_request
      data = JSON.parse(response.body)
      expect(data['html']).to be_kind_of(String)
    end
    it 'includes the advance request ID in its response' do
      make_request
      data = JSON.parse(response.body)
      expect(data['id']).to eq(advance_request.id)
    end
    it 'sets @rate_data' do
      make_request
      expect(assigns[:rate_data]).to eq(rate_data)
    end
    it 'sets @advance_terms' do
      make_request
      expect(assigns[:advance_terms]).to eq(AdvanceRequest::ADVANCE_TERMS)
    end
    it 'sets @advance_types' do
      make_request
      expect(assigns[:advance_types]).to eq(AdvanceRequest::ADVANCE_TYPES)
    end
    it 'calls `advance_request_to_session`' do
      expect(subject).to receive(:render).at_least(:once).ordered
      expect(subject).to receive(:advance_request_to_session).ordered
      make_request
    end
    it 'enables the grace period if called before the desk closes' do
      allow_any_instance_of(EtransactAdvancesService).to receive(:etransact_active?).and_return(true)
      expect(advance_request).to receive(:allow_grace_period=).with(true)
      make_request
    end
    it 'does not enable the grace period if called after the desk closes' do
      allow_any_instance_of(EtransactAdvancesService).to receive(:etransact_active?).and_return(false)
      expect(advance_request).to_not receive(:allow_grace_period=)
      make_request
    end
  end

  describe "POST quick_advance_preview", :vcr do
    allow_policy :advances, :show?
    let(:member_id) {750}
    let(:advance_term) {'1week'}
    let(:advance_type) {'aa'}
    let(:advance_rate) {'0.17'}
    let(:username) {'Test User'}
    let(:advance_description) {double('some description')}
    let(:advance_program) {double('some program')}
    let(:amount) { rand(100010..999999) }
    let(:interest_day_count) { 'some interest_day_count' }
    let(:payment_on) { 'some payment_on' }
    let(:maturity_date) { 'some maturity_date' }
    let(:check_capstock) { true }
    let(:check_result) {{:status => 'pass', :low => 100000, :high => 1000000000}}
    let(:make_request) { post :quick_advance_preview, advance_term: advance_term, advance_type: advance_type, advance_rate: advance_rate, amount: amount }
    let(:advance_request) { double(AdvanceRequest, :type= => nil, :term= => nil, :amount= => nil, :stock_choice= => nil, validate_advance: true, errors: [], sta_debit_amount: 0, timestamp!: nil, amount: amount, id: SecureRandom.uuid) }
    before do
      allow(subject).to receive(:advance_request).and_return(advance_request)
      allow(subject).to receive(:populate_advance_request_view_parameters)
      allow(subject).to receive(:advance_request_to_session)
      allow(subject).to receive(:advance_request_from_session).and_return(advance_request)
    end
    it_behaves_like 'a user required action', :post, :quick_advance_preview
    it_behaves_like 'an authorization required method', :post, :quick_advance_preview, :advances, :show?

    it 'calls `advance_request_from_session`' do
      expect(subject).to receive(:advance_request_from_session).ordered
      expect(advance_request).to receive(:validate_advance).ordered
      make_request
    end
    it 'calls `advance_request_to_session`' do
      expect(subject).to receive(:render).at_least(:once).ordered
      expect(subject).to receive(:advance_request_to_session).ordered
      make_request
    end
    it 'should populate the normal advance view parameters' do
      expect(subject).to receive(:populate_advance_request_view_parameters)
      make_request
    end
    it 'should render its view' do
      make_request
      expect(response.body).to render_template('dashboard/quick_advance_preview')
    end
    it 'should set @session_elevated to the result of calling `session_elevated?`' do
      result = double('needs securid')
      expect(subject).to receive(:session_elevated?).and_return(result)
      make_request
      expect(assigns[:session_elevated]).to be(result)
    end
    it 'should validate the advance' do
      expect(advance_request).to receive(:validate_advance)
      make_request
    end
    it 'sets the advance amount if passed an amount' do
      expect(advance_request).to receive(:amount=).with(amount.to_s)
      make_request
    end
    it 'clears the capital stock choice is passed an amount' do
      expect(advance_request).to receive(:stock_choice=).with(nil)
      make_request
    end
    describe 'the rate is stale' do
      before do
        allow(advance_request).to receive(:errors).and_return([double('An Error', type: :rate, code: :stale)])
      end
      it 'renders the quick_advance_error' do
        make_request
        expect(response).to render_template(:quick_advance_error)
      end
      it 'renders the quick_advance_error withoiut a layout' do
        expect(subject).to receive(:render_to_string).with(:quick_advance_error, layout: false)
        make_request
      end
      it 'sets preview_success to `false`' do
        data = JSON.parse(make_request.body)
        expect(data['preview_success']).to be false
      end
      it 'sets preview_error to `true`' do
        data = JSON.parse(make_request.body)
        expect(data['preview_error']).to be true
      end
    end

    {
      'GrossUpError': {type: :preview, code: :capital_stock_offline},
      'CreditError': {type: :preview, code: :credit},
      'CollateralError': {type: :preview, code: :collateral},
      'ExceedsTotalDailyLimitError': {type: :preview, code: :total_daily_limit},
      'LowLimit': {type: :limits, code: :low},
      'HighLimit': {type: :limits, code: :high}
    }.each do |name, error|
      describe "POST quick_advance_error of type `#{name}`" do
        before do
          error[:value] = nil unless error.has_key?(:value)
          allow(advance_request).to receive(:errors).and_return([double('An Error', error)])
        end
        it 'should render its view' do
          make_request
          expect(response.body).to render_template('dashboard/quick_advance_error')
        end
      end
    end

    describe 'capital stock purchase required' do
      before do
        allow(advance_request).to receive(:errors).and_return([double('An Error', type: :preview, code: :capital_stock, value: nil)])
        allow(subject).to receive(:populate_advance_request_view_parameters) do
          subject.instance_variable_set(:@original_amount, rand(10000..1000000))
          subject.instance_variable_set(:@net_stock_required, rand(1000..9999))
        end
      end
      it 'render its view' do
        make_request
        expect(response.body).to render_template('dashboard/quick_advance_capstock')
      end
      it 'sets the @net_amount instance variable' do
        make_request
        expect(assigns[:net_amount]).to eq(assigns[:original_amount] - assigns[:net_stock_required])
      end
    end

    describe 'collateral and capital stock limit errors' do
      let(:collateral_error) {'collateral error value'}
      before do
        allow(advance_request).to receive(:errors).and_return([double('CollateralError', type: :preview, code: :collateral, value: :collateral_error), double('CapStockError', type: :preview, code: :capital_stock, value: nil)])
      end
      it 'render its view' do
        make_request
        expect(response.body).to render_template('dashboard/quick_advance_error')
      end
      it 'sets the @error_message instance variable' do
        make_request
        expect(assigns[:error_message]).to eq(:collateral)
      end
      it 'sets the @error_value instance variable' do
        make_request
        expect(assigns[:error_value]).to eq(:collateral_error)
      end
    end

    describe 'error priority' do
      before do
        allow(subject).to receive(:populate_advance_request_view_parameters) do
          subject.instance_variable_set(:@original_amount, rand(10000..1000000))
          subject.instance_variable_set(:@net_stock_required, rand(1000..9999))
        end
      end
      {
        rate: [:stale, :unknown, :settings],
        limits: [:unknown, :high, :low],
        preview: [
          :unknown, :capital_stock_offline, :credit,
          :collateral, :total_daily_limit, :disabled_product
        ],
        foo: [:unknown]
      }.each do |type, errors|
        errors.each do |error|
          it "prioritizes #{type}:#{error} over preview:capital_stock" do
            allow(advance_request).to receive(:errors).and_return([
              AdvanceRequest::Error.new(type, error),
              AdvanceRequest::Error.new(:preview, :capital_stock)
            ])
            make_request
            expect(assigns[:error_message]).to be(error)
          end
        end
      end
      it 'shows capital stock gross up if there are no other errors' do
        allow(advance_request).to receive(:errors).and_return([
          AdvanceRequest::Error.new(:preview, :capital_stock)
        ])
        make_request
        expect(response).to render_template(:quick_advance_capstock)
      end
    end
  end

  describe "POST quick_advance_perform", :vcr do
    allow_policy :advances, :show?
    let(:member_id) {750}
    let(:advance_term) {'someterm'}
    let(:advance_type) {'sometype'}
    let(:advance_description) {double('some description')}
    let(:advance_program) {double('some program')}
    let(:advance_rate) {'0.17'}
    let(:username) {'Test User'}
    let(:amount) { 100000 }
    let(:securid_pin) { '1111' }
    let(:securid_token) { '222222' }
    let(:make_request) { post :quick_advance_perform, member_id: member_id, advance_term: advance_term, advance_type: advance_type, advance_rate: advance_rate, amount: amount, securid_pin: securid_pin, securid_token: securid_token }
    let(:securid_service) { SecurIDService.new('a user', test_mode: true) }
    let(:advance_request) { double(AdvanceRequest, expired?: false, executed?: true, execute: nil, sta_debit_amount: 0, errors: [], id: SecureRandom.uuid) }

    before do
      allow(subject).to receive(:session_elevated?).and_return(true)
      allow(SecurIDService).to receive(:new).and_return(securid_service)
      allow(subject).to receive(:populate_advance_request_view_parameters)
      allow(subject).to receive(:advance_request_to_session)
      allow(subject).to receive(:advance_request).and_return(advance_request)
      allow(subject).to receive(:advance_request_from_session).and_return(advance_request)
    end

    it_behaves_like 'a user required action', :post, :quick_advance_perform
    it_behaves_like 'an authorization required method', :post, :quick_advance_perform, :advances, :show?
    it 'calls `advance_request_from_session`' do
      expect(subject).to receive(:advance_request_from_session).ordered
      expect(subject).to receive(:session_elevated?).ordered
      make_request
    end
    it 'calls `advance_request_to_session`' do
      expect(subject).to receive(:render).at_least(:once).ordered
      expect(subject).to receive(:advance_request_to_session).ordered
      make_request
    end
    it 'should render the confirmation view on success' do
      make_request
      expect(response.body).to render_template('dashboard/quick_advance_perform')
    end
    it 'should return a JSON response containing the view, the advance status and the securid status' do
      html = SecureRandom.hex
      allow(subject).to receive(:render_to_string).and_return(html)
      make_request
      json = JSON.parse(response.body)
      expect(json['html']).to eq(html)
      expect(json['securid']).to eq(RSA::SecurID::Session::AUTHENTICATED.to_s)
      expect(json['advance_success']).to be(true)
    end
    it 'should check if the session has been elevated' do
      expect(subject).to receive(:session_elevated?).at_least(:once)
      make_request
    end
    it 'should check if the rate has expired' do
      expect(advance_request).to receive(:expired?)
      make_request
    end
    it 'should populate the normal advance view parameters' do
      expect(subject).to receive(:populate_advance_request_view_parameters)
      make_request
    end
    it 'executes the advance' do
      expect(advance_request).to receive(:execute)
      make_request
    end
    describe 'with unelevated session' do
      before do
        allow(subject).to receive(:session_elevated?).and_return(false)
      end
      it 'should return a securid status of `invalid_pin` if the pin is malformed' do
        post :quick_advance_perform, securid_pin: 'foo', securid_token: securid_token
        json = JSON.parse(response.body)
        expect(json['securid']).to eq('invalid_pin')
      end
      it 'should return a securid status of `invalid_token` if the token is malformed' do
        post :quick_advance_perform, securid_token: 'foo', securid_pin: securid_pin
        json = JSON.parse(response.body)
        expect(json['securid']).to eq('invalid_token')
      end
      it 'should authenticate the user via RSA SecurID if the session is not elevated' do
        expect(securid_service).to receive(:authenticate).with(securid_pin, securid_token)
        make_request
      end
      it 'should elevate the session if RSA SecurID authentication succedes' do
        expect(securid_service).to receive(:authenticate).with(securid_pin, securid_token).ordered
        expect(securid_service).to receive(:authenticated?).ordered.and_return(true)
        expect(subject).to receive(:session_elevate!).ordered
        make_request
      end
      it 'should not elevate the session if RSA SecurID authentication fails' do
        expect(securid_service).to receive(:authenticate).with(securid_pin, securid_token).ordered
        expect(securid_service).to receive(:authenticated?).ordered.and_return(false)
        expect(subject).to_not receive(:session_elevate!).ordered
        make_request
      end
      it 'should not perform the advance if the session is not elevated' do
        expect(advance_request).to_not receive(:execute)
        make_request
      end
    end

    describe 'with an expired rate' do
      before do
        allow(advance_request).to receive(:expired?).and_return(true)
      end
      it 'should render a quick advance error' do
        make_request
        expect(response.body).to render_template('dashboard/quick_advance_error')
      end
      it 'should set the error message to `rate_expired`' do
        make_request
        expect(assigns[:error_message]).to eq(:rate_expired)
      end
      it 'should populate the normal advance view parameters' do
        expect(subject).to receive(:populate_advance_request_view_parameters)
        make_request
      end
      it 'should not execute the advance' do
        expect(advance_request).to_not receive(:execute)
        make_request
      end
    end
  end

  describe "GET current_overnight_vrc", :vcr do
    let(:rate_service_instance) {double('RatesService')}
    let(:etransact_service_instance) {double('EtransactAdvancesService')}
    let(:RatesService) {class_double(RatesService)}
    let(:rate) { double('rate') }
    let(:rate_service_response) { double('rate service response', :[] => nil, :[]= => nil) }
    let(:response_hash) { get :current_overnight_vrc; JSON.parse(response.body) }
    it_behaves_like 'a user required action', :get, :current_overnight_vrc
    it 'calls `current_overnight_vrc` on the rate service and `etransact_active?` on the etransact service' do
      allow(RatesService).to receive(:new).and_return(rate_service_instance)
      allow(EtransactAdvancesService).to receive(:new).and_return(etransact_service_instance)
      expect(etransact_service_instance).to receive(:etransact_active?)
      expect(rate_service_instance).to receive(:current_overnight_vrc).and_return({})
      get :current_overnight_vrc
    end
    it 'returns a rate' do
      expect(response_hash['rate']).to be_kind_of(String)
      expect(response_hash['rate'].to_f).to be >= 0
    end
    it 'returns a time stamp for when the rate was last updated' do
      date = DateTime.parse(response_hash['updated_at'])
      expect(date).to be_kind_of(DateTime)
      expect(date).to be <= DateTime.now
    end
    describe 'the rate value' do
      before do
        allow(RatesService).to receive(:new).and_return(rate_service_instance)
        allow(rate_service_instance).to receive(:current_overnight_vrc).and_return(rate_service_response)
        allow(rate_service_response).to receive(:[]).with(:rate).and_return(rate)
      end
      it 'is passed to the `fhlb_formatted_number` helper' do
        expect(subject).to receive(:fhlb_formatted_number).with(rate, {precision: 2, html: false})
        get :current_overnight_vrc
      end
      it 'is set to the returned `fhlb_formatted_number` string' do
        allow(subject).to receive(:fhlb_formatted_number).and_return(rate)
        expect(rate_service_response).to receive(:[]=).with(:rate, rate)
        get :current_overnight_vrc
      end
    end
  end

  RSpec.shared_examples "a deferred job action" do |method|
    it 'calls `deferred_job_data`' do
      expect(subject).to receive(:deferred_job_data)
      get method
    end
    it 'is successful even if `deferred_job_data` returns nil' do
      allow(subject).to receive(:deferred_job_data).and_return(nil)
      get method
      expect(response.status).to eq(200)
    end
  end

  describe 'GET recent_activity' do
    let(:recent_activity) { get :recent_activity }
    let(:activity_1) { double('activity') }
    let(:activity_2) { double('another activity') }
    let(:activities) { [activity_1, activity_2] }
    let(:processed_activities) { double('processed_activities') }

    before do
      allow(subject).to receive(:process_recent_activities)
      allow(subject).to receive(:deferred_job_data).and_return(activities)
      [activity_1, activity_2].each do |activity|
        allow(activity).to receive(:with_indifferent_access)
      end
      allow(subject).to receive(:render)
    end
    it_behaves_like 'a deferred job action', :recent_activity
    it_behaves_like 'a user required action', :get, :recent_activity
    it 'calls `with_indifferent_access` on the hashes contained in the activities array' do
      [activity_1, activity_2].each do |activity|
        expect(activity).to receive(:with_indifferent_access)
      end
      recent_activity
    end
    it 'processes the activities hash' do
      expect(subject).to receive(:process_recent_activities).with(activities)
      recent_activity
    end
    it 'renders the `dashboard_recent_activity` partial with the correct data' do
      allow(subject).to receive(:process_recent_activities).and_return(processed_activities)
      expect(subject).to receive(:render).with({partial: 'dashboard/dashboard_recent_activity', locals: {table_data: processed_activities}, layout: false})
      recent_activity
    end
  end

  describe 'GET account_overview' do
    total_borrowing_capacity_keys = %i(total_borrowing_capacity_sbc_agency total_borrowing_capacity_sbc_aaa total_borrowing_capacity_sbc_aa)
    ([:sta_balance, :remaining_financing_available, :total, :remaining, :remaining_leverage, :credit_outstanding, :collateral_borrowing_capacity, :capital_stock, :total_borrowing_capacity_standard] + total_borrowing_capacity_keys).each do |attr|
      let(attr) { double(attr.to_s) }
    end
    let(:nested_hash) { double('hash') }
    let(:borrowing_capacity_gauge) { double('borrowing capacity guage') }
    let(:account_overview) { get :account_overview }
    let(:profile) {
      {
        sta_balance: sta_balance,
        remaining_financing_available: remaining_financing_available,
        credit_outstanding: credit_outstanding,
        collateral_borrowing_capacity: collateral_borrowing_capacity,
        capital_stock: capital_stock,
        total_borrowing_capacity_standard: total_borrowing_capacity_standard,
        total_borrowing_capacity_sbc_agency: total_borrowing_capacity_sbc_agency,
        total_borrowing_capacity_sbc_aaa: total_borrowing_capacity_sbc_aaa,
        total_borrowing_capacity_sbc_aa: total_borrowing_capacity_sbc_aa
      }
    }
    before do
      allow(subject).to receive(:deferred_job_data)
      allow(subject).to receive(:render)
      allow_any_instance_of(MembersService).to receive(:report_disabled?).and_return(false)
      allow_any_instance_of(MemberBalanceService).to receive(:borrowing_capacity_summary).and_return(borrowing_capacity_summary)
    end

    it_behaves_like 'a user required action', :get, :account_overview
    it_behaves_like 'a deferred job action', :account_overview
    it 'renders without a layout' do
      expect(subject).to receive(:render).with(layout: false).and_call_original
      account_overview
    end
    it 'checks the profile for disabled endpoints' do
      expect(subject).to receive(:sanitize_profile_if_endpoints_disabled).and_return({})
      account_overview
    end
    it 'calculates the borrowing capacity gauge using the borrowing capacity hash from the service' do
      expect(subject).to receive(:calculate_borrowing_capacity_gauge).with(borrowing_capacity_summary)
      account_overview
    end
    it 'sets @borrowing_capacity_gauge to the result of `calculate_borrowing_capacity_gauge`' do
      allow(subject).to receive(:calculate_borrowing_capacity_gauge).and_return(borrowing_capacity_gauge)
      account_overview
      expect(assigns[:borrowing_capacity_gauge]).to eq(borrowing_capacity_gauge)
    end
    it 'does not set @borrowing_capacity_gauge if the COLLATERAL_REPORT_DATA (i.e. Borrowing Capacity) report is disabled' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(anything, [MembersService::COLLATERAL_REPORT_DATA]).and_return(true)
      account_overview
      expect(assigns[:borrowing_capacity_gauge]).to be_nil
    end
    describe 'the `@account_overview_table_data` instance variable' do
      before do
        allow(subject).to receive(:sanitize_profile_if_endpoints_disabled).and_return(profile)
        allow(credit_outstanding).to receive(:[]).with(:total).and_return(total)
        allow(collateral_borrowing_capacity).to receive(:[]).with(:remaining).and_return(remaining)
        allow(capital_stock).to receive(:[]).with(:remaining_leverage).and_return(remaining_leverage)
      end
      it 'contains the correct `credit_outstanding` data' do
        account_overview
        expect(assigns[:account_overview_table_data][:credit_outstanding]).to eq([[I18n.t('dashboard.your_account.table.credit_outstanding'), total]])
      end
      it 'contains the correct `sta_balance` data' do
        account_overview
        expect(assigns[:account_overview_table_data][:sta_balance]).to eq([[[I18n.t('dashboard.your_account.table.balance'), reports_settlement_transaction_account_path], sta_balance, I18n.t('dashboard.your_account.table.balance_footnote')]])
      end
      describe '`remaining_borrowing_capacity` data' do
        it 'is nil if `total_borrowing_capacity` is zero' do
          borrowing_capacity_summary[:total_borrowing_capacity] = 0
          allow_any_instance_of(MemberBalanceService).to receive(:borrowing_capacity_summary).and_return(borrowing_capacity_summary)
          account_overview
          expect(assigns[:account_overview_table_data][:remaining_borrowing_capacity]).to be_nil
        end
        it 'contains all of the remaining borrowing capacity subtypes if they have a total borrowing capacity' do
          bc_array = [
            {title: I18n.t('dashboard.your_account.table.remaining_borrowing_capacity')},
            [I18n.t('dashboard.your_account.table.remaining.standard'), borrowing_capacity_summary[:standard_excess_capacity]],
            [I18n.t('dashboard.your_account.table.remaining.agency'), borrowing_capacity_summary[:sbc][:collateral][:agency][:remaining_borrowing_capacity]],
            [I18n.t('dashboard.your_account.table.remaining.aaa'), borrowing_capacity_summary[:sbc][:collateral][:aaa][:remaining_borrowing_capacity]],
            [I18n.t('dashboard.your_account.table.remaining.aa'), borrowing_capacity_summary[:sbc][:collateral][:aa][:remaining_borrowing_capacity]]
          ]
          account_overview
          expect(assigns[:account_overview_table_data][:remaining_borrowing_capacity]).to eq(bc_array)
        end
        it 'does not include the `remaining_standard_bc` if the `total_standard_bc` is 0' do
          borrowing_capacity_summary[:net_plus_securities_capacity] = 0
          allow_any_instance_of(MemberBalanceService).to receive(:borrowing_capacity_summary).and_return(borrowing_capacity_summary)
          account_overview
          expect(assigns[:account_overview_table_data][:remaining_borrowing_capacity]).not_to include([I18n.t('dashboard.your_account.table.remaining.standard'), borrowing_capacity_summary[:standard_excess_capacity]])
        end
        ['agency', 'aaa', 'aa'].each do |sbc_type|
          it "does not include the `remaining_#{sbc_type}_bc` if the `total_#{sbc_type}_bc` is 0" do
            borrowing_capacity_summary[:sbc][:collateral][sbc_type.to_sym][:total_borrowing_capacity] = 0
            allow_any_instance_of(MemberBalanceService).to receive(:borrowing_capacity_summary).and_return(borrowing_capacity_summary)
            account_overview
            expect(assigns[:account_overview_table_data][:remaining_borrowing_capacity]).not_to include([I18n.t("dashboard.your_account.table.remaining.#{sbc_type}"), borrowing_capacity_summary[:sbc][:collateral][sbc_type.to_sym][:remaining_borrowing_capacity]])
          end
        end
      end
      describe '`other_remaining` data' do
        let(:other_remaining_array) {
          [
            {title: I18n.t('dashboard.your_account.table.remaining.title')},
            [I18n.t('dashboard.your_account.table.remaining.available'), remaining_financing_available]
          ]
        }
        it 'contains the correct data when the capital stock position and leverage report feature is enabled' do
          other_remaining_array << [[I18n.t('dashboard.your_account.table.remaining.leverage'), reports_capital_stock_and_leverage_path], remaining_leverage]
          account_overview
          expect(assigns[:account_overview_table_data][:other_remaining]).to eq(other_remaining_array)
        end
        it 'contains the correct data when the capital stock position and leverage report feature is disabled' do
          allow(controller).to receive(:feature_enabled?).with('report-capital-stock-position-and-leverage').and_return(false)
          other_remaining_array << [I18n.t('dashboard.your_account.table.remaining.leverage'), remaining_leverage]
          account_overview
          expect(assigns[:account_overview_table_data][:other_remaining]).to eq(other_remaining_array)
        end
      end
    end
  end

  describe 'calculate_gauge_percentages private method' do
    let(:foo_capacity) { rand(1000..2000) }
    let(:bar_capacity) { rand(1000..2000) }
    let(:total_borrowing_capacity) { foo_capacity + bar_capacity }
    let(:capacity_hash) do
      {
        total: total_borrowing_capacity,
        foo: foo_capacity,
        bar: bar_capacity
      }
    end
    let(:call_method) { subject.send(:calculate_gauge_percentages, capacity_hash, :total) }
    it 'does not raise an exception if total_borrowing_capacity is zero' do
      capacity_hash[:total] = 0
      expect {subject.send(:calculate_gauge_percentages, capacity_hash, :total)}.to_not raise_error
    end
    it 'does not raise an exception if a key has `nil` for a value' do
      capacity_hash[:foo] = nil
      expect {subject.send(:calculate_gauge_percentages, capacity_hash, :total)}.to_not raise_error
    end
    it 'does not return a total percentage > 100% even if the total is less than the sum of all the keys' do
      capacity_hash[:total] = 0
      call_method.each do |key, segment|
        expect(segment[:display_percentage]).to be <= 100
      end
    end
    it 'converts the capacties into gauge hashes' do
      gauge_hash = call_method
      expect(gauge_hash[:foo]).to include(:amount, :percentage, :display_percentage)
      expect(gauge_hash[:bar]).to include(:amount, :percentage, :display_percentage)
      expect(gauge_hash[:total]).to include(:amount, :percentage, :display_percentage)
    end
    it 'does not include the excluded keys values in calculating display_percentage' do
      expect(call_method[:total][:display_percentage]).to eq(100)
    end
    it 'treats negative numbers as zero' do
      negative_hash = capacity_hash.dup
      negative_hash[:negative] = rand(-2000..-1000)
      results = call_method
      negative_results = subject.send(:calculate_gauge_percentages, negative_hash, :total)
      expect(negative_results[:foo]).to eq(results[:foo])
      expect(negative_results[:bar]).to eq(results[:bar])
      expect(negative_results[:total]).to eq(results[:total])
    end
  end

  RSpec.shared_examples "an advance_request method" do |method|
    it 'should initialize the advance_request hash if it doesn\'t exist' do
      session['advance_request'] = nil
      subject.send(method)
      expect(session['advance_request']).to be_kind_of(Hash)
    end
    it 'should not initialize the advance_request hash if it exists' do
      hash = {}
      session['advance_request'] = hash
      subject.send(method)
      expect(session['advance_request']).to equal(hash)
    end
  end

  describe '`populate_advance_request_view_parameters` method' do
    let(:call_method) { subject.send(:populate_advance_request_view_parameters) }
    let(:advance_request) { double('An AdvanceRequest').as_null_object }
    before do
      allow(subject).to receive(:advance_request).and_return(advance_request)
    end
    it 'should get the advance request' do
      expect(subject).to receive(:advance_request)
      call_method
    end
    {
      authorized_amount: :authorized_amount,
      cumulative_stock_required: :cumulative_stock_required,
      current_trade_stock_required: :current_trade_stock_required,
      pre_trade_stock_required: :pre_trade_stock_required,
      net_stock_required: :net_stock_required,
      gross_amount: :gross_amount,
      gross_cumulative_stock_required: :gross_cumulative_stock_required,
      gross_current_trade_stock_required: :gross_current_trade_stock_required,
      gross_pre_trade_stock_required: :gross_pre_trade_stock_required,
      gross_net_stock_required: :gross_net_stock_required,
      human_interest_day_count: :human_interest_day_count,
      human_payment_on: :human_payment_on,
      trade_date: :trade_date,
      funding_date: :funding_date,
      maturity_date: :maturity_date,
      initiated_at: :initiated_at,
      advance_number: :confirmation_number,
      advance_amount: :amount,
      advance_term: :human_term,
      advance_raw_term: :term,
      advance_rate: :rate,
      advance_description: :term_description,
      advance_type: :human_type,
      advance_type_raw: :type,
      advance_program: :program_name,
      collateral_type: :collateral_type,
      old_rate: :old_rate,
      rate_changed: :rate_changed?,
      total_amount: :total_amount
    }.each do |param, method|
      it "should populate the view variable `@#{param}` with the value found on the advance request for attribute `#{method}`" do
        value = double("Advance Request Parameter: #{method}")
        allow(advance_request).to receive(method).and_return(value)
        call_method
        expect(assigns[param]).to eq(value)
      end
    end
  end

  describe '`advance_request` protected method' do
    let(:call_method) { subject.send(:advance_request) }
    let(:advance_request) { double(AdvanceRequest, owners: double(Set, add: nil)) }
    it 'returns a new AdvanceRequest if the controller is lacking one' do
      member_id = double('A Member ID')
      signer = double('A Signer')
      allow(subject).to receive(:current_member_id).and_return(member_id)
      allow(subject).to receive(:signer_full_name).and_return(signer)
      allow(AdvanceRequest).to receive(:new).with(member_id, signer, subject.request).and_return(advance_request)
      expect(call_method).to be(advance_request)
    end
    it 'returns the AdvanceRequest stored in `@advance_request` if present' do
      subject.instance_variable_set(:@advance_request, advance_request)
      expect(call_method).to be(advance_request)
    end
    it 'adds the current user to the owners list' do
      allow(AdvanceRequest).to receive(:new).and_return(advance_request)
      expect(advance_request.owners).to receive(:add).with(subject.current_user.id)
      call_method
    end
  end

  describe '`advance_request_from_session` protected method' do
    let(:id) { double('An ID') }
    let(:call_method) { subject.send(:advance_request_from_session, id) }
    let(:advance_request) { double(AdvanceRequest, owners: double(Set, member?: true), class: AdvanceRequest) }

    shared_examples 'modify authorization' do
      it 'checks if the current user is allowed to modify the advance' do
        expect(subject).to receive(:authorize).with(advance_request, :modify?)
        call_method
      end
      it 'raises a Pundit::NotAuthorizedError if the user cant modify the advance' do
        allow(advance_request.owners).to receive(:member?).and_return(false)
        expect{ call_method }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    describe 'without a passed ID' do
      let(:id) { nil }
      before do
        allow(subject).to receive(:advance_request).and_return(advance_request)
      end
      it 'calls `advance_request` if the session has no ID' do
        expect(subject).to receive(:advance_request)
        subject.send(:advance_request_from_session, nil)
      end
      include_examples 'modify authorization'
    end
    describe 'with a passed request ID' do
      before do
        allow(AdvanceRequest).to receive(:find).and_return(advance_request)
      end
      it 'finds the AdvanceRequest by ID' do
        request = double('A Request')
        expect(AdvanceRequest).to receive(:find).with(id, subject.request)
        call_method
      end
      it 'assigns the AdvanceRequest to @advance_request' do
        call_method
        expect(assigns[:advance_request]).to be(advance_request)
      end
      include_examples 'modify authorization'
    end
  end

  describe '`advance_request_to_session` protected method' do
    let(:id) { double('An ID') }
    let(:advance_request) { double(AdvanceRequest, id: id, save: false) }
    let(:call_method) { subject.send(:advance_request_to_session) }
    it 'does nothing if there is no @advance_request' do
      call_method
      expect(session[:advance_request]).to be_nil
    end
    describe 'with an AdvanceRequest' do
      before do
        subject.instance_variable_set(:@advance_request, advance_request)
      end
      it 'saves the AdvanceRequest' do
        expect(advance_request).to receive(:save)
        call_method
      end
    end
  end

  describe '`signer_full_name` protected method' do
    let(:signer) { double('A Signer Name') }
    let(:call_method) { subject.send(:signer_full_name) }
    it 'returns the signer name from the session if present' do
      session['signer_full_name'] = signer
      expect(call_method).to be(signer)
    end
    describe 'with no signer in session' do
      let(:username) { double('A Username') }
      before do
        allow(subject).to receive_message_chain(:current_user, :username).and_return(username)
        allow_any_instance_of(EtransactAdvancesService).to receive(:signer_full_name).with(username).and_return(signer)
      end
      it 'fetches the signer from the eTransact Service' do
        expect_any_instance_of(EtransactAdvancesService).to receive(:signer_full_name).with(username)
        call_method
      end
      it 'sets the signer name in the session' do
        call_method
        expect(session['signer_full_name']).to be(signer)
      end
      it 'returns the signer name' do
        expect(call_method).to be(signer)
      end
    end
  end

  describe '`process_recent_activities` private method' do
    let(:future_date) { Time.zone.today + rand(1000) }
    let(:product_description) { double('product description') }
    let(:current_par) { double('current_par') }
    let(:maturity_date) { double('maturity date') }
    let(:transaction_number) { rand(100000) }
    let(:activity) { { instrument_type: 'LC', transaction_number: transaction_number, current_par: current_par } }
    let(:activities) { [activity, activity, activity, activity, activity, activity] }
    let(:call_method) { controller.send(:process_recent_activities, activities) }
    let(:process_recent_activities) { subject.send(:process_recent_activities, activity) }
    before do
      allow(subject).to receive(:fhlb_date_standard_numeric).and_return(future_date)
    end

    it 'returns an empty array if passed nil' do
      expect(controller.send(:process_recent_activities, nil)).to eq([])
    end
    describe 'a processed activity array' do
      it 'has a current_par in the second position' do
        expect(call_method.first[1]).to eq(current_par)
      end
      it 'has a transaction_number in the fourth position' do
        expect(call_method.first[3]).to eq(transaction_number)
      end
    end
    context 'letters of credit' do
      let(:activity) { [{ instrument_type: 'LC', product_description: 'LC' }] }
      it 'displays `Letter of Credit` when product description is `LC` in the description' do
        expect(process_recent_activities.first[0]).to eq(I18n.t('dashboard.recent_activity.letter_of_credit'))
      end
      let(:activity) { [{ instrument_type: 'LC', product_description: "LC LC LC" }] }
      it 'displays `Letter of Credit` when product description is `LC LC LC` in the description' do
        expect(process_recent_activities.first[0]).to eq(I18n.t('dashboard.recent_activity.letter_of_credit'))
      end
      context 'amended' do
        let(:activity) { [{ instrument_type: 'LC', status: 'INTER_AMEND_STA' }] }
        it 'displays `Amended Today` in the description' do
          expect(process_recent_activities.first[2]).to eq(I18n.t('dashboard.recent_activity.amended_today'))
        end
      end
      context 'terminated' do
        let(:activity) { [{ instrument_type: 'LC', status: 'TERMINATED' }] }
        it 'displays `Terminated Today` in the description' do
          expect(process_recent_activities.first[2]).to eq(I18n.t('dashboard.recent_activity.terminated_today'))
        end
      end
      context 'expired' do
        let(:activity) { [{ instrument_type: 'LC', status: 'EXPIRED' }] }
        it 'displays `Expires Today` in the description' do
          expect(process_recent_activities.first[2]).to eq(I18n.t('dashboard.recent_activity.expires_today'))
        end
      end
      context 'matured' do
        let(:activity) { [{ instrument_type: 'LC', status: 'MATURED' }] }
        it 'displays `Matures Today` in the description' do
          expect(process_recent_activities.first[2]).to eq(I18n.t('dashboard.recent_activity.matures_today'))
        end
      end
      context 'verified' do
        let(:activity) { [{ instrument_type: 'LC', status: 'VERIFIED', maturity_date: future_date }] }
        it 'displays `Matures on [Date]` in the description' do
          expect(process_recent_activities.first[2]).to eq(I18n.t('dashboard.recent_activity.matures_on', date: future_date))
        end
      end
      let(:letter_of_credit_with_unknown_status) { [{ instrument_type: 'LC',
                                             status: 'FOO',
                                             maturity_date: Time.zone.today }] }
      it 'displays `Today` as the event for an advance of an unknown status with a maturity date of today' do
        expect(subject.send(:process_recent_activities, letter_of_credit_with_unknown_status).first[2]).to eq(I18n.t('global.today'))
      end
    end
    context 'advances' do
      context 'full' do
        let(:termination_full_partial) { double(:termination_full_partial, to_s: 'FULL PREPAYMENT') }
        let(:terminated_advance) { [{ instrument_type: 'ADVANCE',
                                      status: 'TERMINATED',
                                      termination_full_partial: termination_full_partial }] }
        it 'displays contents of `termination_full_partial` for terminated advances in description' do
          expect(subject.send(:process_recent_activities, terminated_advance).first[2]).to eq(termination_full_partial)
        end
        let(:verified_advance) { [{ instrument_type: 'ADVANCE',
                                      status: 'VERIFIED',
                                      termination_full_partial: termination_full_partial }] }
        it 'displays contents of `termination_full_partial` for verified advances in description' do
          expect(subject.send(:process_recent_activities, terminated_advance).first[2]).to eq(termination_full_partial)
        end
        let(:advance_with_matured_status) { [{ instrument_type: 'ADVANCE',
                                               status: 'MATURED',
                                               termination_full_partial: termination_full_partial }] }
        it 'displays `Matured Today` in the description' do
          expect(subject.send(:process_recent_activities, advance_with_matured_status).first[2]).to eq(I18n.t('dashboard.recent_activity.matures_today'))
        end
        let(:advance_with_unknown_status) { [{ instrument_type: 'ADVANCE',
                                               status: 'FOO',
                                               maturity_date: Time.zone.today }] }
        it 'displays `Today` as the event for an advance of an unknown status with a maturity date of today' do
          expect(subject.send(:process_recent_activities, advance_with_unknown_status).first[2]).to eq(I18n.t('global.today'))
        end
      end
      context 'partial prepayment' do
        let(:termination_full_partial) { 'PARTIAL PREPAYMENT' }
        let(:amount_paid) { double(Float) }
        let(:partial_vrc_advance) { [{
          instrument_type: 'ADVANCE',
          sub_product: 'VRC - WL',
          termination_full_partial: termination_full_partial,
          termination_par: amount_paid
        }] }
        let(:partial_frc_advance) { [{
          instrument_type: 'ADVANCE',
          sub_product: 'FRC - Wholeloan',
          termination_full_partial: termination_full_partial,
          termination_par: amount_paid
        }] }
        let(:prepayment_event) { I18n.t('dashboard.recent_activity.partial_prepayment') }
        let(:repayment_event) { I18n.t('dashboard.recent_activity.partial_repayment') }
        it 'displays partial repayment for the event of a partially paid VRC advances' do
          expect(subject.send(:process_recent_activities, partial_vrc_advance).first[2]).to eq(repayment_event)
        end
        it 'displays partial repayment for the event of a partially paid FRC advances' do
          expect(subject.send(:process_recent_activities, partial_frc_advance).first[2]).to eq(prepayment_event)
        end
        it 'displays the `termination_par` as the amount for partial payments' do
          results = subject.send(:process_recent_activities, [partial_vrc_advance, partial_frc_advance].flatten)
          expect(results.length).to be(2)
          results.each do |activity|
            expect(activity[1]).to be(amount_paid)
          end
        end
        ['Foo VRC BAR', 'VRC FOO', 'BAR VRC'].each do |sub_product|
          it 'treats an advance with a sub product containing the word VRC as a VRC product' do
            partial_vrc_advance.first[:sub_product] = sub_product
            expect(subject.send(:process_recent_activities, partial_vrc_advance).first[2]).to eq(repayment_event)
          end
        end
        it 'treats an advance with a sub product containing VRC but not as a word as a non-VRC product' do
            partial_frc_advance.first[:sub_product] = 'FOOVRCBAR'
            expect(subject.send(:process_recent_activities, partial_frc_advance).first[2]).to eq(prepayment_event)
          end
      end
      context 'pending termination' do
        let(:advance_with_pend_term_status) { [{ instrument_type: 'ADVANCE', status: 'PEND_TERM' }] }
        it 'displays `Open` for maturity date when status is `PEND_TERM` and there is no maturity date' do
          expect(subject.send(:process_recent_activities, advance_with_pend_term_status).first[2]).to eq(I18n.t('dashboard.open'))
        end
        let(:advance_with_maturity_and_pend_term_status) { [{ instrument_type: 'ADVANCE', status: 'PEND_TERM', maturity_date: future_date }] }
        it 'displays `Matures On` for the maturity date when status is `PEND_TERM` and there is a maturity date' do
          expect(subject.send(:process_recent_activities, advance_with_maturity_and_pend_term_status).first[2]).to eq(I18n.t('dashboard.recent_activity.matures_on', date: future_date))
        end
      end
      context 'forward-funded advances' do
        let(:forward_funded_advance) { [{ instrument_type: 'ADVANCE',
                                          status: 'COLLATERAL_AUTH',
                                          funding_date: future_date }] }
        it 'displays `Will be funded on [Date]` in the description' do
          expect(subject.send(:process_recent_activities, forward_funded_advance).first[2]).to eq(I18n.t('dashboard.recent_activity.will_be_funded_on', date: future_date))
        end
      end
      context 'matured' do
        let(:advance_matured_today) { [{ instrument_type: 'ADVANCE', status: 'MATURED' }] }
        it 'displays `Matures Today` if status is `MATURED`' do
          expect(subject.send(:process_recent_activities, advance_matured_today).first[2]).to eq(I18n.t("dashboard.recent_activity.matures_today"))
        end
      end
      context 'executed' do
        let(:advance_executed) { [{ instrument_type: 'ADVANCE', status: 'EXECUTED', maturity_date: future_date }] }
        it 'displays `Matures [Date]` if status is `EXECUTED`' do
          expect(subject.send(:process_recent_activities, advance_executed).first[2]).to eq(I18n.t('dashboard.recent_activity.matures_on', date: future_date))
        end
      end
      context 'in review' do
        let(:advance_in_ops_review) { [{ instrument_type: 'ADVANCE', status: 'OPS_REVIEW' }] }
        it 'displays `In Review` if status is `OPS_REVIEW`' do
          expect(subject.send(:process_recent_activities, advance_in_ops_review).first[2]).to eq(I18n.t('dashboard.recent_activity.in_review'))
        end
        let(:advance_in_sec_review) { [{ instrument_type: 'ADVANCE', status: 'SEC_REVIEWED' }] }
        it 'displays `In Review` if status is `SEC_REVIEWED`' do
          expect(subject.send(:process_recent_activities, advance_in_sec_review).first[2]).to eq(I18n.t('dashboard.recent_activity.in_review'))
        end
      end
      context 'OPEN VRC' do
        let(:open_vrc) { [{ instrument_type: 'ADVANCE', status: 'VERIFIED', product: 'OPEN VRC' }] }
        it 'displays `Open` for any `OPEN VRC` product' do
          expect(subject.send(:process_recent_activities, open_vrc).first[2]).to eq(I18n.t('dashboard.open'))
        end
        let(:advance_in_sec_review) { [{ instrument_type: 'ADVANCE', status: 'SEC_REVIEWED' }] }
        it 'displays `In Review` if status is `SEC_REVIEWED`' do
          expect(subject.send(:process_recent_activities, advance_in_sec_review).first[2]).to eq(I18n.t('dashboard.recent_activity.in_review'))
        end
      end
    end
    context 'investments' do
      let(:investment_with_matured_status) { [{ instrument_type: 'INVESTMENT', maturity_date: Time.zone.today }] }
      it 'displays `Matured Today` for investments maturing today' do
        expect(subject.send(:process_recent_activities, investment_with_matured_status).first[2]).to eq(I18n.t('dashboard.recent_activity.matures_today'))
      end
      let(:investment_maturing_in_the_future) { [{ instrument_type: 'INVESTMENT', maturity_date: future_date }] }
      it 'displays `Matures on [Date]` for investments maturing in the future`' do
        expect(subject.send(:process_recent_activities, investment_maturing_in_the_future).first[2]).to eq(I18n.t('dashboard.recent_activity.matures_on', date: future_date))
      end
      let(:investment_with_no_maturity_date) { [{ instrument_type: 'INVESTMENT', maturity_date: nil }] }
      it 'displays `Open` for investments without maturing dates`' do
        expect(subject.send(:process_recent_activities, investment_with_no_maturity_date).first[2]).to eq(I18n.t('dashboard.open'))
      end
      let(:investment_terminated) { [{instrument_type: 'INVESTMENT', status: 'TERMINATED', maturity_date: future_date}] }
      it 'displays the maturity date for the event when the investment is TERMINATED' do
        formatted_date = SecureRandom.hex
        allow(controller).to receive(:fhlb_date_standard_numeric).with(future_date).and_return(formatted_date)
        expect(subject.send(:process_recent_activities, investment_terminated).first[2]).to eq(formatted_date)
      end
    end
    context 'other instrument types' do
      let(:deposit) { [{ instrument_type: 'DEPOSIT' }] }
      let(:simpletransfer) { [{ instrument_type: 'SIMPLETRANSFER' }] }
      let(:ca) { [{ instrument_type: 'CA' }] }
      let(:bonds) { [{ instrument_type: 'BONDS' }] }
      let(:mm) { [{ instrument_type: 'MM' }] }
      let(:repo) { [{ instrument_type: 'REPO' }] }
      let(:whatever) { [{ instrument_type: 'WHATEVER' }] }
      it 'does not return activities with any other instrument types' do
        [deposit, simpletransfer, ca, bonds, mm, repo, whatever].each do |activity|
          expect(subject.send(:process_recent_activities, activity)).to eq([])
        end
      end
    end
  end

  describe '`deferred_job_data` private method' do
    let(:request) { double('request') }
    let(:action_name) { %w(foo wizz bang bar).sample }
    let(:params) { double('params hash') }
    let(:param_name) { double('param_name') }
    let(:user_id) { rand(1..9999) }
    let(:job_status_as_string) { double('job status as string') }
    let(:job_status) { double('an instance of JobStatus', result_as_string: job_status_as_string, destroy: nil) }
    let(:job) { double('an instance of the MemberBalanceTodaysCreditActivityJob', job_status: job_status) }
    let(:current_user) { double('User', id: user_id)}
    let(:parsed_response) { double('parsed response') }
    let(:call_method) { subject.send(:deferred_job_data) }
    before do
      allow(subject).to receive(:request).and_return(request)
      allow(subject).to receive(:params).and_return(params)
      allow(subject).to receive(:action_name).and_return(action_name)
      allow(params).to receive(:[]).with("#{action_name}_job_id".to_sym).and_return(param_name)
      allow(request).to receive(:xhr?).and_return(true)
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(JobStatus).to receive(:find_by).and_return(job_status)
      allow(JSON).to receive(:parse).and_return(parsed_response)
    end
    it 'raises an exception when the request is not XHR' do
      allow(request).to receive(:xhr?).and_return(false)
      expect{call_method}.to raise_exception(/Invalid request/)
    end
    it 'raises an ArgumentError if no `recent_activity_job_id` param is passed' do
      allow(params).to receive(:[])
      expect{call_method}.to raise_error(ArgumentError)
    end
    it 'finds the JobStatus by id, user_id and status' do
      expect(JobStatus).to receive(:find_by).with(id: param_name, user_id: user_id, status: JobStatus.statuses[:completed]).and_return(job_status)
      call_method
    end

    it 'raises an exception if no JobStatus is found' do
      allow(JobStatus).to receive(:find_by)
      expect{call_method}.to raise_error(ActiveRecord::RecordNotFound )
    end
    it 'destroys the job_status' do
      expect(job_status).to receive(:destroy)
      call_method
    end
    it 'returns the JSON-parsed job status' do
      allow(parsed_response).to receive(:clone).and_return(parsed_response)
      allow(job_status_as_string).to receive(:dup).and_return(job_status_as_string)
      allow(JSON).to receive(:parse).with(job_status_as_string).and_return(parsed_response)
      expect(call_method).to eq(parsed_response)
    end
  end

  describe '`populate_deferred_jobs_view_parameters` private method' do
    let(:name) { %w(foo wizz bang bar).sample }
    let(:job_status) { double('job status', update_attributes!: nil, id: job_id) }
    let(:job_klass) { double('FhlbJob', perform_later: double('job instance', job_status: job_status)) }
    let(:path) { %w(some path helpers as strings).sample }
    let(:current_user) { double('User', id: user_id)}
    let(:job_id) { double('job id') }
    let(:user_id) { double('user id') }
    let(:member_id) { double('memer id') }
    let(:job_status_url) { double('job status url') }
    let(:load_url) { double('load url') }
    let(:uuid) { double('uuid of request') }
    let(:call_method) { controller.send(:populate_deferred_jobs_view_parameters, {:"#{name}" => [job_klass, path]}) }

    before do
      allow(controller).to receive(:current_user).and_return(current_user)
      allow(controller).to receive(:current_member_id).and_return(member_id)
      allow(controller).to receive(:send).and_call_original
      allow(controller).to receive(:send).with(path, anything)
    end
    describe 'calling `perform_later` on the passed job_klass' do
      it 'passes member_id as an argument' do
        expect(job_klass).to receive(:perform_later).with(member_id, anything).and_return(double('job instance', job_status: job_status))
        call_method
      end
      it 'passes the uuid of the request object if one is available' do
        allow(request).to receive(:uuid).and_return(uuid)
        expect(job_klass).to receive(:perform_later).with(anything, uuid).and_return(double('job instance', job_status: job_status))
        call_method
      end
      it 'passes nil as an argument if there is no request object' do
        expect(job_klass).to receive(:perform_later).with(anything, nil).and_return(double('job instance', job_status: job_status))
        call_method
      end
    end
    it 'updates the job_status with the user id' do
      expect(job_status).to receive(:update_attributes!).with({user_id: user_id})
      call_method
    end
    it 'sets a job status url instance variable' do
      allow(controller).to receive(:job_status_url).with(job_status).and_return(job_status_url)
      call_method
      expect(assigns[:"#{name}_job_status_url"]).to eq(job_status_url)
    end
    it 'sets a load url instance variable' do
      allow(controller).to receive(:send).with(path, {:"#{name}_job_id" => job_id}).and_return(load_url)
      call_method
      expect(assigns[:"#{name}_load_url"]).to eq(load_url)
    end
  end

  describe '`sanitize_profile_if_endpoints_disabled` private method' do
    [:total_financing_available, :sta_balance, :total, :remaining, :capital_stock].each do |attr|
      let(attr) { double(attr.to_s) }
    end
    let(:profile) do
      {
        total_financing_available: total_financing_available,
        sta_balance: sta_balance,
        credit_outstanding: {total: total},
        collateral_borrowing_capacity: {remaining: remaining},
        capital_stock: capital_stock
      }
    end
    let(:empty_profile) { {credit_outstanding: {}, collateral_borrowing_capacity: {}} }
    let(:member_id) { double('member id') }
    let(:call_method) { controller.send(:sanitize_profile_if_endpoints_disabled, profile) }

    before do
      allow(controller).to receive(:current_member_id).and_return(member_id)
      allow_any_instance_of(MembersService).to receive(:report_disabled?)
    end

    it 'returns `{credit_outstanding: {}, collateral_borrowing_capacity: {}}` if nil is passed in' do
      expect(controller.send(:sanitize_profile_if_endpoints_disabled, nil)).to eq(empty_profile)
    end
    it 'returns `{credit_outstanding: {}, collateral_borrowing_capacity: {}}` if an empty hash is passed in' do
      expect(controller.send(:sanitize_profile_if_endpoints_disabled, {})).to eq(empty_profile)
    end
    [:total_financing_available, :sta_balance, :capital_stock, [:credit_outstanding, :total], [:collateral_borrowing_capacity, :remaining]].each do |attr|
      if attr.is_a?(Symbol)
        it "returns the original value of `#{attr}` if no flag is set" do
          expect(call_method[attr]).to eq(send(attr))
        end
      else
        it "returns the original value of `[#{attr.first}][#{attr.last}]` if no flag is set" do
          expect(call_method[attr.first][attr.last]).to eq(send(attr.last))
        end
      end
    end
    it 'sets the `total_financing_available` to nil if the MembersService::FINANCING_AVAILABLE_DATA flag is set' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::FINANCING_AVAILABLE_DATA]).and_return(true)
      expect(call_method[:total_financing_available]).to be_nil
    end
    it 'sets the `sta_balance` to nil if the MembersService::STA_BALANCE_AND_RATE_DATA flag is set' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, array_including(MembersService::STA_BALANCE_AND_RATE_DATA)).and_return(true)
      expect(call_method[:sta_balance]).to be_nil
    end
    it 'sets the `sta_balance` to nil if the MembersService::STA_DETAIL_DATA flag is set' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, array_including(MembersService::STA_DETAIL_DATA)).and_return(true)
      expect(call_method[:sta_balance]).to be_nil
    end
    it 'sets the `credit_outstanding.total` to nil if the MembersService::CREDIT_OUTSTANDING_DATA flag is set' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::CREDIT_OUTSTANDING_DATA]).and_return(true)
      expect(call_method[:credit_outstanding][:total]).to be_nil
    end
    it 'sets the `capital_stock` to nil if the MembersService::FHLB_STOCK_DATA flag is set' do
      allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::FHLB_STOCK_DATA]).and_return(true)
      expect(call_method[:capital_stock]).to be_nil
    end
    describe 'the MembersService::COLLATERAL_HIGHLIGHTS_DATA flag is set' do
      before { allow_any_instance_of(MembersService).to receive(:report_disabled?).with(member_id, [MembersService::COLLATERAL_HIGHLIGHTS_DATA]).and_return(true) }
      it 'sets the `[:collateral_borrowing_capacity][:remaining]` to nil' do
        expect(call_method[:collateral_borrowing_capacity][:remaining]).to be_nil
      end
      %i(total_borrowing_capacity_standard total_borrowing_capacity_sbc_agency total_borrowing_capacity_sbc_aaa total_borrowing_capacity_sbc_aa).each do |key|
        it "sets the `[#{key}]` to nil" do
          expect(call_method[key]).to be_nil
        end
      end
    end
  end

  describe 'the `calculate_borrowing_capacity_gauge` private method' do
    let(:borrowing_capacity_gauge) { controller.send(:calculate_borrowing_capacity_gauge, borrowing_capacity_summary) }
    let(:breakdown_hash) { double('breakdown hash') }
    let(:total_borrowing_capacity) { borrowing_capacity_summary[:total_borrowing_capacity] }
    let(:total_standard_bc) { borrowing_capacity_summary[:net_plus_securities_capacity] }
    let(:remaining_standard_bc) { borrowing_capacity_summary[:standard_excess_capacity] }
    let(:used_standard_bc) { total_standard_bc - remaining_standard_bc }
    let(:total_agency_bc) { borrowing_capacity_summary[:sbc][:collateral][:agency][:total_borrowing_capacity] }
    let(:remaining_agency_bc) { borrowing_capacity_summary[:sbc][:collateral][:agency][:remaining_borrowing_capacity] }
    let(:used_agency_bc) { total_agency_bc - remaining_agency_bc }
    let(:total_aaa_bc) { borrowing_capacity_summary[:sbc][:collateral][:aaa][:total_borrowing_capacity] }
    let(:remaining_aaa_bc) { borrowing_capacity_summary[:sbc][:collateral][:aaa][:remaining_borrowing_capacity] }
    let(:used_aaa_bc) { total_aaa_bc - remaining_aaa_bc }
    let(:total_aa_bc) { borrowing_capacity_summary[:sbc][:collateral][:aa][:total_borrowing_capacity] }
    let(:remaining_aa_bc) { borrowing_capacity_summary[:sbc][:collateral][:aa][:remaining_borrowing_capacity] }
    let(:used_aa_bc) { total_aa_bc - remaining_aa_bc }
    before do
      allow(controller).to receive(:calculate_gauge_percentages).and_call_original
    end
    it 'handles being passed an empty hash' do
      expect{controller.send(:calculate_borrowing_capacity_gauge, {})}.not_to raise_exception
    end
    describe 'when `total_borrowing_capacity` is 0' do
      before do
        borrowing_capacity_summary[:total_borrowing_capacity] = 0
        allow(controller).to receive(:calculate_gauge_percentages).and_return(total: {})
      end
      it 'calls `calculate_gauge_percentages` with `{total: 0}`' do
        expect(controller).to receive(:calculate_gauge_percentages).with({total: 0}).and_return(total: {})
        borrowing_capacity_gauge
      end
      ['standard_percentage', 'sbc_percentage'].each do |collateral_type|
        it "sets `#{collateral_type}` to 0" do
          expect(borrowing_capacity_gauge[:total][collateral_type.to_sym]).to eq(0)
        end
      end
    end
    it 'calculates the first-level gauge percentages with the totals of the collateral types' do
      first_level_hash = {
          total: total_borrowing_capacity,
          mortgages: total_standard_bc,
          agency: total_agency_bc,
          aaa: total_aaa_bc,
          aa: total_aa_bc
        }
      expect(controller).to receive(:calculate_gauge_percentages).with(first_level_hash, :total)
      borrowing_capacity_gauge
    end
    [:mortgages, :agency, :aaa, :aa].each do |collateral_type|
      describe "`#{collateral_type}` breakdown values" do
        let(:breakdown_hash) do
          case collateral_type
            when :mortgages
              {
                total: total_standard_bc,
                remaining: remaining_standard_bc,
                used: used_standard_bc
              }
            when :agency
              {
                total: total_agency_bc,
                remaining: remaining_agency_bc,
                used: used_agency_bc
              }
            when :aaa
              {
                total: total_aaa_bc,
                remaining: remaining_aaa_bc,
                used: used_aaa_bc
              }
            when :aa
              {
                total: total_aa_bc,
                remaining: remaining_aa_bc,
                used: used_aa_bc
              }
          end
        end
        it "calls `calculate_gauge_percentages` with the proper values for the `#{collateral_type.to_s}` breakdown" do
          expect(controller).to receive(:calculate_gauge_percentages).with(breakdown_hash, :total)
          borrowing_capacity_gauge
        end
        it "sets `borrowing_capacity_gauge[#{collateral_type}][:breakdown]` to the result of calling `calculate_gauge_percentages`" do
          allow(controller).to receive(:calculate_gauge_percentages).with(breakdown_hash, :total).and_return(breakdown_hash)
          expect(borrowing_capacity_gauge[collateral_type][:breakdown]).to eq(breakdown_hash)
        end
      end
    end
    describe 'collateral type total percentages' do
      let(:first_level_hash) {
        {
          total: total_borrowing_capacity,
          mortgages: total_standard_bc,
          agency: total_agency_bc,
          aaa: total_aaa_bc,
          aa: total_aa_bc
        }
      }
      let(:bc_percentages_hash) {
        {
          mortgages: {percentage: rand()},
          agency: {percentage: rand()},
          aaa: {percentage: rand()},
          aa: {percentage: rand()},
          total: {}
        }
      }
      before do
        allow(controller).to receive(:calculate_gauge_percentages).with(first_level_hash, :total).and_return(bc_percentages_hash)
      end
      it 'sets `[:total][:standard_percentage]` to the percentage value for `mortgages` returned by `calculate_gauge_percentages`' do
        expect(borrowing_capacity_gauge[:total][:standard_percentage]).to eq(bc_percentages_hash[:mortgages][:percentage])
      end
      it 'sets `[:total][:sbc_percentage]` to the sum of the percentage values for `agency`, `aaa` and `aa` returned by `calculate_gauge_percentages`' do
        total_sbc_percentage = bc_percentages_hash[:agency][:percentage] + bc_percentages_hash[:aaa][:percentage] + bc_percentages_hash[:aa][:percentage]
        expect(borrowing_capacity_gauge[:total][:sbc_percentage]).to eq(total_sbc_percentage)
      end
    end
  end

end