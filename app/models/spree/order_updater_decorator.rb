Spree::OrderUpdater.class_eval do

  attr_reader :refresh_rates
  def initialize(order, options = {})
    @order = order
    @refresh_rates = (options[:refresh_rates].present? ? options[:refresh_rates] : true)
  end

  # give each of the shipments a chance to update themselves
  # at the end of
  def update_shipments
    shipments.each do |shipment|
      next unless shipment.persisted?
      shipment.update!(order)
      shipment.refresh_rates if @refresh_rates
      shipment.update_amounts
    end
  end
end