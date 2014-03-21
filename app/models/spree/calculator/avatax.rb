require_dependency 'spree/calculator'

module Spree
  class Calculator < ActiveRecord::Base
    class Avatax < Calculator
      attr_accessor :pager_duty_client

      include Spree::Calculator::DefaultTaxMethods
      
      def self.description
        I18n.t(:avalara_tax)
      end

      def compute(computable)
        case computable
          when Spree::Order
            avatax_compute_order(computable)
          when Spree::LineItem
            avatax_compute_line_item(computable)
        end
      end

      def doc_type
        'SalesOrder'
      end

      def status_field
        :avatax_response_at
      end

      def build_line_items(order)
        order.line_items.select do |line_item|
          line_item.product.tax_category == rate.tax_category
        end
      end
  
      private
  
      def rate
        self.calculable
      end

      def avatax_compute_order(order)
        # This is called in Spree 2-1
        SpreeAvatax::AvataxComputer.new.compute_order_with_context(order, self)
      end
  
      def avatax_compute_line_item(line_item)
        # This is called in Spree 2-2 :(
        order = Rails.cache.fetch(cache_key(line_item.order), expires_in: 1.minute) do
          SpreeAvatax::AvataxComputer.new.compute_order_with_context(line_item.order, self)
          line_item.order
        end
        tax_line_item = order.line_items.select { |li| li.id = line_item.id }.first
        tax_line_item.additional_tax_total
      end

      ##
      # Build a cache key contain line items + orders + timestamps for changes
      #
      def cache_key(order)
        order.line_items.map do |li|
          "#{li.id}#{li.updated_at.to_f}"
        end.join("") + "#{order.id}#{order.updated_at.to_f}"
      end
    end
  end
end
