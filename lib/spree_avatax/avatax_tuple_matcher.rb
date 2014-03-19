require_relative 'avatax_tuple'

##
# Let's not assume that the line_items we send to Avatax return in the same order. 
# Match instead on the line_no to match the Spree::LineItem with Avatax Request Response line items.
#

module SpreeAvatax
  class AvataxTupleMatcher
    def add_tuple(tuple)
      raise "NO AVATAX REQUEST LINE" if tuple.avatax_request_line.nil?
      raise "NO SPREE LINE ITEM" if tuple.spree_line_item.nil?
      raise "NO LINE NUMBER" if tuple.avatax_request_line['LineNo'].nil?

      store[tuple.avatax_request_line['LineNo'].to_i] = tuple
      true
    end

    def backfill_avatax_response_tax_line(avatax_response_tax_line)
      tuple = store[avatax_response_tax_line.line_no.to_i]
      raise "NO TUPLE FOUND" if tuple.nil?
      tuple.avatax_response_tax_line = avatax_response_tax_line
      true
    end
  
    def store
      @store ||= {}
    end
  end
end
