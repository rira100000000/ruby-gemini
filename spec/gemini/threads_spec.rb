require 'spec_helper'
require 'time'

RSpec.describe Gemini::Threads do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:threads) { Gemini::Threads.new(client: client) }

  describe '#create' do
    context 'with basic parameters only' do
      it 'creates a thread and returns ID' do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        allow(Time).to receive(:now).and_return(Time.at(1234567890))

        result = threads.create

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890,
          'metadata' => {}
        )
      end
    end

    context 'with metadata specified' do
      it 'creates a thread with metadata' do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        allow(Time).to receive(:now).and_return(Time.at(1234567890))
        
        metadata = { 'user_id' => '123', 'session' => 'abc' }
        result = threads.create(parameters: { metadata: metadata })

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890,
          'metadata' => metadata
        )
      end
    end

    context 'with model specified' do
      it 'creates a thread with specified model' do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        
        result = threads.create(parameters: { model: 'gemini-2.0-pro' })
        
        # Model info is not included in direct return value, check internal state
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-pro')
      end
    end
  end

  describe '#retrieve' do
    context 'with existing thread' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        allow(Time).to receive(:now).and_return(Time.at(1234567890))
        threads.create
      end

      it 'retrieves thread information' do
        result = threads.retrieve(id: 'test-thread-id')

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890,
          'metadata' => {}
        )
      end
    end

    context 'with non-existent thread' do
      it 'raises an error' do
        expect {
          threads.retrieve(id: 'non-existent-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end
  end

  describe '#modify' do
    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
      allow(Time).to receive(:now).and_return(Time.at(1234567890))
      threads.create
    end

    context 'modifying metadata' do
      it 'updates thread metadata' do
        new_metadata = { 'user_id' => '456', 'priority' => 'high' }
        result = threads.modify(id: 'test-thread-id', parameters: { metadata: new_metadata })

        expect(result['metadata']).to eq(new_metadata)
        # Verify other attributes remain unchanged
        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890
        )
      end
    end

    context 'modifying model' do
      it 'updates thread model' do
        threads.modify(id: 'test-thread-id', parameters: { model: 'gemini-2.0-pro' })
        
        # Check internal state with get_model
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-pro')
      end
    end

    context 'with non-existent thread' do
      it 'raises an error' do
        expect {
          threads.modify(id: 'non-existent-id', parameters: { metadata: {} })
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end
  end

  describe '#delete' do
    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
      threads.create
    end

    context 'with existing thread' do
      it 'deletes the thread' do
        result = threads.delete(id: 'test-thread-id')

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread.deleted',
          'deleted' => true
        )

        # Verify access after deletion raises error
        expect {
          threads.retrieve(id: 'test-thread-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end

    context 'with non-existent thread' do
      it 'raises an error' do
        expect {
          threads.delete(id: 'non-existent-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end
  end

  describe '#get_model' do
    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
      threads.create(parameters: { model: 'gemini-2.0-flash-lite' })
    end

    context 'with existing thread' do
      it 'retrieves thread model' do
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-flash-lite')
      end
    end

    context 'with non-existent thread' do
      it 'raises an error' do
        expect {
          threads.get_model(id: 'non-existent-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end
  end
end