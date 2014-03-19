require 'spec_helper'

describe SpreeAvatax::AvataxTupleMatcher do
  let(:spree_line_item) { double(Spree::LineItem) }
  let(:avatax_request_line) {  Avalara::Request::Line.new(line_no: '7', destination_code: 'Code', origin_code: 'Fred', qty: 1, amount: 10.00) }
  let(:tuple) { SpreeAvatax::AvataxTuple.new(avatax_request_line: avatax_request_line, spree_line_item: spree_line_item) }
  let(:matcher) { SpreeAvatax::AvataxTupleMatcher.new }

  describe '#add_tuple' do
    subject { matcher.add_tuple(tuple) }

    it 'should return true' do
      subject.should be_true
    end

    it 'should add an item to the store' do
      subject
      matcher.store[7].should == tuple
      matcher.store.size.should == 1
    end
  end 

  describe '#backfill_avatax_response_tax_line' do
    let(:avatax_response_tax_line) { double(Avalara::Response::TaxLine, line_no: '7') }

    subject { matcher.backfill_avatax_response_tax_line(avatax_response_tax_line) }
  
    before do
      matcher.add_tuple(tuple)
    end

    it 'should return true' do
      subject.should be_true 
    end

    it 'should have populated the tuple' do
      subject
      matcher.store[7].avatax_response_tax_line.should == avatax_response_tax_line
    end
  end
end
