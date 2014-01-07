require 'spec_helper'

describe Spree::Order do
  let(:order) do
     FactoryGirl.create(:order, ship_address: FactoryGirl.create(:ship_address))
  end

  describe 'commit_avatax_invoice' do
    subject { order.commit_avatax_invoice }

    before do
      Avalara.should_receive(:get_tax).once
    end

    it 'should call Avatax.get_tax' do
      subject
    end
  end
end