require "spec_helper"

describe Minion::Message do
  let(:header) do
    stub.quacks_like(AMQP::Header.allocate)
  end
  
  let(:serialized) do
    '{"content":{"field":"value"}, "callbacks":["minion.second", "minion.third"]}'
  end
  
  subject do
    Minion::Message.new(serialized, header)
  end
  
  its(:content){ should eql({"field"=>"value"}) }
  its(:callbacks){ should eql ["minion.second", "minion.third"] }
  its(:headers){ should eql [header]}
  
  context "when callback is executed" do
    
    let(:data) do
      {'callbacks' => ['minion.third'], 'headers' => [], 'content' => {'field' => 'value'}}
    end
  
    before do
      subject.headers.clear
      subject.headers.expects(:clear)
    end
    
    it "should enqueue the next job" do
      Minion.expects(:enqueue).with('minion.second', data)
      subject.callback
    end
    
  end
  
end
