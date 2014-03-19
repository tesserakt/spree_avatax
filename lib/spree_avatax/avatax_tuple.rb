module SpreeAvatax
  class AvataxTuple
    attr_accessor :spree_line_item, :avatax_request_line, :avatax_response_tax_line

    def initialize(options = {})
      @spree_line_item = options[:spree_line_item]
      @avatax_request_line = options[:avatax_request_line]
      @avatax_response_tax_line = options[:avatax_response_tax_line]
    end
  end
end
