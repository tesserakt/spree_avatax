require 'spec_helper'

describe Spree::Calculator::Avatax do
  let(:calculator) { Spree::Calculator::Avatax.new }
  let(:tax_category) { 'Foo' }
  let(:tax_rate) { double(Spree::TaxRate, amount: 50.00, tax_category: tax_category) }

  describe 'Avatax.description' do
    it 'should not be nil' do
      Spree::Calculator::Avatax.description.should_not be_nil
    end
  end

  describe 'compute' do
    subject { calculator.compute(computable) }

    context 'when computable is Spree::Order' do
      let(:computable) { Spree::Order.new }

      before do
        calculator.should_receive(:avatax_compute_order).once
        calculator.should_receive(:avatax_compute_line_item).never       
      end

      it 'should call compute order' do
        subject
      end
    end

    context 'when computable is Spree::LineItem' do
      let(:computable) { Spree::LineItem.new }

      before do
        calculator.should_receive(:avatax_compute_order).never
        calculator.should_receive(:avatax_compute_line_item).once
      end

      it 'should call compute order' do
        subject
      end
    end
  end 

  describe 'rate' do
    subject { calculator.send(:rate) }
    it 'should calculate a rate' do
      # TODO: Come up with a better test for rate.
      subject.should be_nil
    end  
  end

  describe 'build_line_items' do
    let(:order) { create :order_with_line_items }

    before do
      order.line_items.each do |line_item|
        line_item.product.stub(:tax_category).and_return(tax_category)
      end
      calculator.should_receive(:rate).at_least(order.line_items.size).and_return(tax_rate)
    end

    it 'should return all line items' do
      calculator.build_line_items(order).size.should == order.line_items.size 
    end
  end

  describe 'doc_type' do
    it 'should return SalesInvoice' do
      calculator.doc_type.should == 'SalesOrder'
    end
  end

  describe 'status_field' do
    it 'should return :avatax_invoice_at' do
      calculator.status_field.should == :avatax_response_at
    end
  end

  describe 'avatax_compute_order' do
    let(:order) { create :order }

    subject { calculator.send(:avatax_compute_order, order) }

    it 'should call SpreeAvatax::AvataxCalculator.compute_order' do
      SpreeAvatax::AvataxComputer.any_instance.should_receive(:compute_order_with_context).once.with(order, calculator)
      subject
    end
  end

  describe 'avatax_compute_line_item' do
    let(:line_item) { FactoryGirl.create(:line_item) }
    let(:order) { line_item.order }
    let(:cache_key) { calculator.send(:cache_key, order) }

    subject { calculator.send(:avatax_compute_line_item, line_item) }

    it 'should call compute_order_with_context' do
      SpreeAvatax::AvataxComputer.any_instance.should_receive(:compute_order_with_context).once.with(line_item.order, calculator)
      subject
    end

    it 'writes to the cache' do
      subject
      Rails.cache.exist?(cache_key) 
    end

    it 'tries to read from the cache' do
      Rails.cache.should_receive(:fetch).once.and_return(order)
      subject
    end
  end

  describe 'cache_key' do
    let(:order) { create :order_with_line_items }

    subject { calculator.send(:cache_key, order) }

    it 'should contain the order id and order updated_at' do
      subject.should include(order.id.to_s)
      subject.should include(order.updated_at.to_f.to_s)
    end

    it 'should contain each line item id and updated_at' do
      order.line_items.each do |line_item|
        subject.should include(line_item.id.to_s)
        subject.should include(line_item.updated_at.to_f.to_s)
      end
    end
  end
end
