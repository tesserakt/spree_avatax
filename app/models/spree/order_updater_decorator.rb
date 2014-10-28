Spree::OrderUpdater.class_eval do

  attr_reader :refresh_rates
  def initialize(order, options = {})
    @order = order
    if options && options.has_key?(:refresh_rates)
      @refresh_rates = options[:refresh_rates]
    else
      @refresh_rates = true
    end
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
