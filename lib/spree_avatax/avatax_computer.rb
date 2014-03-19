module SpreeAvatax
  class AvataxComputer
    DEFAULT_TAX_AMOUNT = 0

    def avatax_logger
      @@avatax_logger ||= Logger.new("#{Rails.root}/log/avatax.log")
    end

    def compute_order_with_context(order, context)

      raise "MUST IMPLEMENT DOC TYPE" unless context.respond_to?(:doc_type)
      raise "MUST IMPLEMENT BUILD LINE ITEMS" unless context.respond_to?(:build_line_items)
      raise "MUST IMPLEMENT STATUS FIELD" unless context.respond_to?(:status_field)

      # Do not calculate tax if no ship address or no line items.
      return DEFAULT_TAX_AMOUNT if order.ship_address.nil?
      return DEFAULT_TAX_AMOUNT if order.line_items.blank?

      # Use Avatax lookup and if fails fall back to default Spree taxation rules
      begin
        Avalara.password = SpreeAvatax::Config.password
        Avalara.username = SpreeAvatax::Config.username
        Avalara.endpoint = SpreeAvatax::Config.endpoint

        # Need to force update state before calculating
        # We were not getting up to date information before sending to Avatax
        Spree::OrderUpdater.new(order).update_totals

        tuple_matcher = SpreeAvatax::AvataxTupleMatcher.new
        
        matched_line_items = context.build_line_items(order)
        return DEFAULT_TAX_AMOUNT if matched_line_items.blank?
        
        invoice = build_invoice(order, context)
        invoice.addresses = build_invoice_addresses(order)
        invoice.lines = build_invoice_lines(order, matched_line_items, tuple_matcher)

        # Log request
        avatax_logger.debug invoice.to_s
        invoice_tax = Avalara.get_tax(invoice)

        # Map the line items taxes to the order
        associate_line_item_taxes(invoice_tax, tuple_matcher)
       
        # Indicate this order was Avatax calculated 
        order.update_column(context.status_field, Time.now)

        # Log response
        avatax_logger.debug invoice_tax.to_s
        invoice_tax.total_tax
      # Handle only Avalara Errors
      # https://github.com/adamfortuna/avalara/blob/master/lib/avalara/errors.rb
      rescue Avalara::ApiError, Avalara::TimeoutError, Avalara::Error => e
        avatax_logger.error(e)
        notify(e, order)
        order.update_column(context.status_field, nil)

        # Return 0 for and let Finance/Accounting deal with this 
        DEFAULT_TAX_AMOUNT 
      end
    end

    ##
    # For each line item received from avatax, backfill the response to the tuple, then update the Spree::LineItem
    #
    def associate_line_item_taxes(invoice_tax, avatax_tuple_matcher)
      invoice_tax.tax_lines.each do |tax_line|
        avatax_tuple_matcher.backfill_avatax_response_tax_line(tax_line)
      end 

      # http://developer.avalara.com/api-docs/rest/tax/post
      avatax_tuple_matcher.store.each_pair do |line_no, tuple|
        tuple.spree_line_item.additional_tax_total = BigDecimal.new(tuple.avatax_response_tax_line.tax.to_s)
      end
    end

    def build_invoice(order, context)
      Avalara::Request::Invoice.new(
        :customer_code => order.email,
        :doc_date => Date.today,
        :doc_type => context.doc_type,
        :company_code => SpreeAvatax::Config.company_code,
        :discount => order_discount(order).to_s,
        :doc_code => order.number
      )
    end

    def order_discount(order)
      # The order discount is the sum of all eligible promotions
      order.adjustments.promotion.eligible.sum(:amount).to_f.abs
    end

    def line_item_amount(line_item)
      # Need to calculate the price * quantity MINUS the eligible promotions on the line item.
      # line_item.final_amount unfortunately returns the previous tax adjustment.
      (line_item.price.to_f * line_item.quantity) - line_item.adjustments.promotion.eligible.sum(:amount).to_f.abs
    end

    def build_invoice_addresses(order)
      [
        Avalara::Request::Address.new(
          :address_code => '1',
          :line_1 => order.ship_address.address1.to_s,
          :line_2 => order.ship_address.address2.to_s,
          :city => order.ship_address.city.to_s,
          :postal_code => order.ship_address.zipcode.to_s
        )
      ]  
    end

    def build_invoice_lines(order, matched_line_items, tuple_matcher)
      line_count = 0
      invoice_lines = []
      matched_line_items.each do |matched_line_item|
        line_count = line_count + 1
        invoice_line = Avalara::Request::Line.new(
          :line_no => line_count.to_s,
          :destination_code => '1',
          :origin_code => '1',
          :qty => matched_line_item.quantity.to_s,
          # Contains the amount * quantity - any line item discount
          :amount => line_item_amount(matched_line_item).to_s,
          :item_code => matched_line_item.variant.sku,
          # Continue to pass this field if we have an order-level discount i.e. % off or $ off
          :discounted => order_discount(order) > 0 ? true : false
        )
        invoice_lines << invoice_line
     
        # Add a tuple for matching later with response line items 
        tuple_matcher.add_tuple(SpreeAvatax::AvataxTuple.new(
          spree_line_item: matched_line_item,
          avatax_request_line: invoice_line 
        )) 
     
      end
      invoice_lines
    end

    ##
    # Notify a Honeybadger that Avalara is down.... :(
    #
    def notify(e, order)
      # Allow certain errors to be not be raised to the alert framework
      # https://github.com/adamfortuna/avalara/blob/master/lib/avalara.rb#L96-L102
      return if e.instance_of?(Avalara::ApiError) && SpreeAvatax::Config.suppress_api_errors?

      alert_params = {
        :error_class   => "Avalara Error: #{e.class}",
        :error_message => "Avalara Error: #{e.message}",
        :parameters    => {order: order.attributes}
      }

      # Notify Honeybadger if the class exists.
      # We assume that it's been configured properly.
      if defined?(Honeybadger)
        Honeybadger.notify(alert_params)
      end
    end
  end
end
