class ContentManagementService
  attr_reader :api, :member_id, :request

  DOCUMENT_MAPPING = {
    credit_guide: {
      type: 'guide',
      uid: 'credit'
    },
    collateral_guide: {
      type: 'guide',
      uid: 'collateral'
    },
    advances_security_agreement_commercial_banks: {
      type: 'form',
      uid: 'advances-security-agreement-commercial-banks'
    },
    advances_security_agreement_community_development: {
      type: 'form', 
      uid: 'advances-security-agreement-community-development'
    },
    advances_security_agreement_credit_unions: {
      type: 'form', 
      uid: 'advances-security-agreement-credit-unions'
    },
    advances_security_agreement_insurance_companies: {
      type: 'form', 
      uid: 'advances-security-agreement-insurance-companies'
    }, 
    letter_of_credit_reimbursement_agreement: {
      type: 'form', 
      uid: 'letter-of-credit-reimbursement-agreement'
    },
    safekeeping_agreement: {
      type: 'form', 
      uid: 'safekeeping-agreement'
    },
    settlement_transaction_account_agreement: {
      type: 'form', 
      uid: 'settlement-transaction-account-agreement'
    },
    resolution_authorization_member_transactions: {
      type: 'form', 
      uid: 'resolution-authorization-member-transactions'
    },
    authorization_entire_authority: {
      type: 'form', 
      uid: 'authorization-entire-authority'
    },
    authorization_wire_transfer_services: {
      type: 'form', 
      uid: 'authorization-wire-transfer-services'
    },
    authorization_advances: {
      type: 'form', 
      uid: 'authorization-advances'
    },
    authorization_affordable_housing_program: {
      type: 'form', 
      uid: 'authorization-affordable-housing-program'
    },
    authorization_collateral: {
      type: 'form', 
      uid: 'authorization-collateral'
    },
    authorization_money_market_transaction: {
      type: 'form', 
      uid: 'authorization-money-market-transaction'
    },
    authorization_securities_services: {
      type: 'form', 
      uid: 'authorization-securities-services'
    },
    authorization_repetitive_wire_instructions: {
      type: 'form', 
      uid: 'authorization-repetitive-wire-instructions'
    },
    authorization_capital_stock_redemption_notice: {
      type: 'form', 
      uid: 'authorization-capital-stock-redemption-notice'
    },
    authorization_portal_access_manager: {
      type: 'form', 
      uid: 'authorization-portal-access-manager'
    },
    authorization_securid_token_request: {
      type: 'form', 
      uid: 'authorization-securid-token-request'
    },
    credit_application_cip_and_ace: {
      type: 'form', 
      uid: 'credit-application-cip-and-ace'
    },
    ace_application_sba_lenders: {
      type: 'form', 
      uid: 'ace-application-sba-lenders'
    },
    statement_of_authority_advances_partial_prepayment: {
      type: 'form', 
      uid: 'statement-of-authority-advances-partial-prepayment'
    },
    statement_of_authority_putable_advances: {
      type: 'form', 
      uid: 'statement-of-authority-putable-advances'
    },
    blanket_lien_real_estate_pledging_reporting_designation: {
      type: 'form',
      uid: 'blanket-lien-real-estate-pledging-reporting-designation'
    },
    anti_predatory_lending_policy_certification_blanket_lien: {
      type: 'form',
      uid: 'anti-predatory-lending-policy-certification-blanket-lien'
    },
    blanket_lien_collateral_eligibility_commercial_banks: {
      type: 'form',
      uid: 'blanket-lien-collateral-eligibility-commercial-banks'
    },
    blanket_lien_collateral_certification_credit_unions: {
      type: 'form', 
      uid: 'blanket-lien-collateral-certification-credit-unions'
    },
    blanket_lien_mcu_notification_detailed_reporting: {
      type: 'form', 
      uid: 'blanket-lien-mcu-notification-detailed-reporting'
    },
    cfi_blanket_lien_collateral_certification: {
      type: 'form', 
      uid: 'cfi-blanket-lien-collateral-certification'
    },
    cfi_blanket_lien_collateral_release_request_certification: {
      type: 'form',
      uid: 'cfi-blanket-lien-collateral-release-request-certification'
    },
    specific_identification_mcu_data_transmission_set_up: {
      type: 'form',
      uid: 'specific-identification-mcu-data-transmission-set-up'
    },
    specific_identification_mcu_transmittal_letter: {
      type: 'form', 
      uid: 'specific-identification-mcu-transmittal-letter'
    },
    specific_identification_mcu_data_field_questionnaire: {
      type: 'form',
      uid: 'specific-identification-mcu-data-field-questionnaire'
    },
    pledge_of_time_deposit_account: {
      type: 'form', 
      uid: 'pledge-of-time-deposit-account'
    },
    pledge_of_securities: {
      type: 'form', 
      uid: 'pledge-of-securities'
    },
    securities_release_request: {
      type: 'form', 
      uid: 'securities-release-request'
    },
    safekeeping_deposit_request: {
      type: 'form', 
      uid: 'safekeeping-deposit-request'
    },
    safekeeping_release_request: {
      type: 'form', 
      uid: 'safekeeping-release-request'
    },
    corporation_assignment_template: {
      type: 'form', 
      uid: 'corporation-assignment-template'
    },
    amendment_to_corporate_credit_union_security_agreement: {
      type: 'form',
      uid: 'amendment-to-corporate-credit-union-security-agreement'
    },
    subordination_agreement_credit_unions: {
      type: 'form', 
      uid: 'subordination-agreement-credit-unions'
    }
  }.freeze

  def initialize(member_id, request)
    @member_id = member_id
    @request = request
    @api = Prismic.api(url, access_token)
  end

  def get_document(cms_key)
    cms_info = DOCUMENT_MAPPING[cms_key]
    raise ArgumentError, "Invalid `cms_key`: `#{cms_key}`" if cms_info.blank?
    begin
      api.get_by_uid(cms_info[:type], cms_info[:uid], ref: ref)
    rescue Prismic::Error => e
      Rails.logger.error("Prismic CMS error for fhlb_id `#{member_id}`, request_uuid `#{request.try(:uuid)}`: #{e.class.name}")
      Rails.logger.error e.backtrace.join("\n")
      return nil
    end
  end

  def get_attribute_as_text(cms_key, api_id)
    fragments = get_document(cms_key).try(:fragments)
    if fragments
      fragments[api_id.to_s].try(:as_text)
    end
  end

  def get_attribute_as_html(cms_key, api_id)
    fragments = get_document(cms_key).try(:fragments)
    if fragments
      fragments[api_id.to_s].try(:as_html, "#{DOCUMENT_MAPPING[cms_key][:type]}.#{api_id}")
    end
  end

  def get_file_download_url(cms_key)
    fragments = get_document(cms_key).try(:fragments)
    if fragments
      fragments['file-download'].try(:url)
    end
  end

  def get_slices_by_type(cms_key, slice_type)
    document = get_document(cms_key)
    if document
      document.get_slice_zone("#{DOCUMENT_MAPPING[cms_key][:type]}.body").slices.select {|slice| slice.slice_type == slice_type.to_s }
    end
  end

  def get_date(cms_key, date_field)
    document = get_document(cms_key)
    if document
      document.get_date("#{DOCUMENT_MAPPING[cms_key][:type]}.#{date_field}").try(:value).try(:to_date)
    end
  end

  private

  def access_token
    @access_token ||= (ENV['PRISMIC_ACCESS_TOKEN'] || config['token'])
  end

  def config
    @config ||= YAML.load(ERB.new(File.new(Rails.root + "config/prismic.yml").read).result)
  end

  def ref
    @ref ||= if ENV['PRISMIC_REF']
      api.ref(ENV['PRISMIC_REF']).try(:ref) || api.master.ref
    else
      api.master.ref
    end
  end

  def url
    @url ||= (ENV['PRISMIC_URL'] || config['url'])
  end
end