require 'spec_helper'

describe SpreeAvatax::AvataxComputer do
  let(:total_tax) { 5.00 }
  let(:computer) { SpreeAvatax::AvataxComputer.new }
  let(:tax_rate) { double(Spree::TaxRate, amount: 50.00, tax_category: 'Foo') }
  let(:invoice_tax) { double(Avalara::Response, total_tax: total_tax, tax_lines: []) }
  let(:order) { FactoryGirl.create(:order_with_line_items, ship_address: FactoryGirl.create(:ship_address)) }
  let(:tuple_matcher) { SpreeAvatax::AvataxTupleMatcher.new }
  let(:context) do  
    order.stub(:build_line_items).and_return(order.line_items)
    order
  end

  describe 'associate_line_item_taxes' do
    let(:tax_lines) do
      [
        double(Avalara::Response::TaxLine, line_no: '1', tax: 9.99)
      ]
    end

    let(:invoice_tax) { double(Avalara::Response, total_tax: total_tax, tax_lines: tax_lines) }
      
    before do
      tuple_matcher.add_tuple(SpreeAvatax::AvataxTuple.new(
        spree_line_item: order.line_items.first,
        avatax_request_line: Avalara::Request::Line.new(line_no: '1', destination_code: 'Code', origin_code: 'Fred', qty: 1, amount: 10.00)
      ))
    end

    subject do
      computer.associate_line_item_taxes(invoice_tax, tuple_matcher)
    end

    it 'should have assigned the tax line to the tuple' do
      subject
      tuple_matcher.store[1].avatax_response_tax_line.should_not be_nil
    end

    it 'should assign 9.99 to line_item tax' do
      subject
      order.line_items.first.additional_tax_total.to_f.should == 9.99
    end
  end

  describe 'build_invoice_lines' do
    subject do
      computer.build_invoice_lines(order, order.line_items, tuple_matcher)
    end

    it 'should have 5 invoice lines' do
      subject.size.should == 5
    end

    it 'should contain Avalara::Request::Line' do
      subject.first.should be_a(Avalara::Request::Line)
    end

    it 'should have 5 tuples in the tuple matcher' do
      subject
      tuple_matcher.store.size.should == 5
    end
  end

  describe 'build_invoice' do
    subject do
      computer.build_invoice(order, context)
    end

    it 'should be a Avalara::Request::Invoice' do
      subject.should be_a(Avalara::Request::Invoice)
    end
  end

  describe 'build_invoice_addresses' do
    subject do
      computer.build_invoice_addresses(order)
    end

    it 'should be size 1' do
      subject.size.should == 1
    end

    it 'should contain a Avalara::Request::Invoice' do
      subject.first.should be_a(Avalara::Request::Address)
    end
  end

  describe 'computer_order_with_context' do
    subject do
      computer.compute_order_with_context(order, context)
    end

    context 'when invalid context' do
      let(:context) { 'FOO' } 

      it 'raises error' do
        lambda {
          subject 
        }.should raise_error
      end
    end

    context 'when build_line_items returns blank' do
      before do
        context.stub(:build_line_items).and_return([])
      end

      it 'should not notify Honeybadger' do
        Honeybadger.should_receive(:notify).never 
        subject
      end

      it 'should return 0' do
        subject.should == 0
      end
    end

    context 'when invalid order' do
      before do
        Avalara.should_receive(:get_tax).never
      end

      context 'when no shipping address' do
        before do
          order.ship_address = nil
        end

        it 'should return 0' do
          subject.should == 0
        end
      end

      context 'when no line items' do
        before do
          order.line_items.delete_all
        end

        it 'should return 0' do
          subject.should == 0
        end
      end
    end

    context 'when valid order and context as order' do
      context 'when computing a Spree:Order' do
        before do
          computer.should_receive(:associate_line_item_taxes).once
          Avalara.should_receive(:get_tax).once.and_return(invoice_tax)
        end

        it 'should return total_tax' do
          subject.should == total_tax
        end

        it 'should set avatax_invoice_at' do
          subject
          order.avatax_invoice_at.should_not be_nil    
        end
      end
    end

    context 'when Avalara::ApiError is raised' do
      context 'when suppress_api_errors is true' do
        before do
          Avalara.should_receive(:get_tax).once.and_raise(Avalara::ApiError.new)
          SpreeAvatax::Config.should_receive(:suppress_api_errors?).and_return(true)
        end

        it 'should not notify Honeybadger' do
          Honeybadger.should_receive(:notify).never
          subject
        end
      end

      context 'when suppress_api_errors is false' do
        before do
          Avalara.should_receive(:get_tax).once.and_raise(Avalara::ApiError.new)
          SpreeAvatax::Config.should_receive(:suppress_api_errors?).and_return(false)
        end

        it 'should notify Honeybadger' do
          Honeybadger.should_receive(:notify).once
          subject
        end
      end
    end

    context 'when StandardError is raised' do
      before do
        Avalara.should_receive(:get_tax).once.and_raise('SOME ERROR')
      end

      it 'should raise error' do
        lambda {
          subject
        }.should raise_error('SOME ERROR')
      end
    end
  end
end
