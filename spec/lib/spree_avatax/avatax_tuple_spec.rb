require 'spec_helper' 

describe SpreeAvatax::AvataxTuple do
  describe '.initialize' do
    it 'should populate options' do
      tuple = SpreeAvatax::AvataxTuple.new(spree_line_item: 'A', avatax_request_line: 'B', avatax_response_tax_line: 'C')
      tuple.spree_line_item.should == 'A'
      tuple.avatax_request_line.should == 'B'
      tuple.avatax_response_tax_line.should == 'C' 
    end
  end
end
