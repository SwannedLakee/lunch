module ViewHelper
  def format_currency number
    number_to_currency(number, precision: 0, format: "#{number.to_i == 0 ? '%n' : '%u%n'}")
  end
end