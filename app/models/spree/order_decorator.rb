Spree::Order.class_eval do

  ##
  # Possible order states
  # http://guides.spreecommerce.com/user/order_states.html

  # Send Avatax the invoice after ther order is complete
  Spree::Order.state_machine.after_transition :to => :complete, :do => :commit_avatax_invoice

  def avataxable?
    line_items.present? && ship_address.present?
  end

  def promotion_adjustment_total
    adjustments.promotion.eligible.sum(:amount).abs
  end

  private

  ##
  # This method sends an invoice to Avalara which is stored in their system.
  def commit_avatax_invoice
    SpreeAvatax::TaxComputer.new(self, { doc_type: 'SalesInvoice', status_field: :avatax_invoice_at }).compute
  end

  ##
  # Comute avatax but do not commit it their db
  def avatax_compute_tax
     SpreeAvatax::TaxComputer.new(self).compute
  end
end
