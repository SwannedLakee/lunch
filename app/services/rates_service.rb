class RatesService
  def initialize
    @connection = ::RestClient::Resource.new Rails.configuration.mapi.endpoint
  end

  def overnight_vrc(days=30)
    response = @connection['rates/historic/overnight'].get params: {limit: days}
    data = JSON.parse(response.body)
    data.collect! do |row|
      [Date.parse(row[0]), row[1].to_f]
    end
  end

  def quick_advance_rates(member_id)
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?

    # TODO: hit the proper MAPI endpoint, once it exists! In the meantime, always return the fake.
    # if @connection
    #   # hit the proper MAPI endpoint
    # else
    #   JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_rates.json'))).with_indifferent_access
    # end

    JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_rates.json'))).with_indifferent_access
  end

  def quick_advance_preview(member_id, advance_type, advance_term, rate)
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?
    raise ArgumentError, 'advance_type must not be blank' if advance_type.blank?
    raise ArgumentError, 'advance_term must not be blank' if advance_term.blank?
    raise ArgumentError, 'rate must not be blank' if rate.blank?

    # TODO: hit the proper MAPI endpoint, once it exists! In the meantime, always return the fake.
    # if @connection
    #   # hit the proper MAPI endpoint
    # else
    #   JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_preview.json'))).with_indifferent_access
    # end

    data = JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_preview.json'))).with_indifferent_access
    data[:funding_date] = data[:funding_date].gsub('-', ' ')
    data[:maturity_date] = data[:maturity_date].gsub('-', ' ')
    data
  end

  def quick_advance_confirmation(member_id, advance_type, advance_term, rate)
    raise ArgumentError, 'member_id must not be blank' if member_id.blank?
    raise ArgumentError, 'advance_type must not be blank' if advance_type.blank?
    raise ArgumentError, 'advance_term must not be blank' if advance_term.blank?
    raise ArgumentError, 'rate must not be blank' if rate.blank?

    # TODO: hit the proper MAPI endpoint, once it exists! In the meantime, always return the fake.
    # if @connection
    #   # hit the proper MAPI endpoint
    # else
    #   JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_confirmation.json'))).with_indifferent_access
    # end

    data = JSON.parse(File.read(File.join(Rails.root, 'db', 'service_fakes', 'quick_advance_confirmation.json'))).with_indifferent_access
    data[:funding_date] = data[:funding_date].gsub('-', ' ')
    data[:maturity_date] = data[:maturity_date].gsub('-', ' ')
    data
  end

end