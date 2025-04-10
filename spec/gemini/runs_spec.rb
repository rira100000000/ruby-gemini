require 'spec_helper'
require 'time'

RSpec.describe Gemini::Runs do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:threads) { instance_double('Gemini::Threads') }
  let(:messages) { instance_double('Gemini::Messages') }
  let(:runs) { Gemini::Runs.new(client: client) }
  let(:thread_id) { 'test-thread-id' }
  let(:run_id) { 'test-run-id' }

  before do
    allow(client).to receive(:threads).and_return(threads)
    allow(client).to receive(:messages).and_return(messages)
    allow(SecureRandom).to receive(:uuid).and_return(run_id)
    allow(Time).to receive(:now).and_return(Time.at(1234567890))
    
    # Thread existence check method
    allow(threads).to receive(:retrieve).with(id: thread_id).and_return({ 'id' => thread_id })
    
    # Thread model retrieval method
    allow(threads).to receive(:get_model).with(id: thread_id).and_return('gemini-2.0-flash-lite')
    
    # Message list retrieval mock
    allow(messages).to receive(:list).with(thread_id: thread_id).and_return({
      'data' => [
        {
          'id' => 'message-1',
          'role' => 'user',
          'content' => [
            { 'text' => { 'value' => 'Hello, how are you?' } }
          ]
        }
      ]
    })
    
    # Chat response mock
    allow(client).to receive(:chat).and_return({
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'text' => 'I am fine, thank you for asking!' }
            ]
          }
        }
      ]
    })
    
    # Message creation mock
    allow(messages).to receive(:create).and_return({
      'id' => 'response-message-id',
      'role' => 'model',
      'content' => [
        { 'type' => 'text', 'text' => { 'value' => 'I am fine, thank you for asking!' } }
      ]
    })
  end

  describe '#create' do
    context 'with valid thread ID' do
      it 'creates a new run and returns result' do
        result = runs.create(thread_id: thread_id)

        expect(result).to include(
          'id' => run_id,
          'object' => 'thread.run',
          'created_at' => 1234567890,
          'thread_id' => thread_id,
          'status' => 'completed',
          'model' => 'gemini-2.0-flash-lite'
        )
        
        # Verify message was created
        expect(messages).to have_received(:create).with(
          thread_id: thread_id,
          parameters: {
            role: 'model',
            content: 'I am fine, thank you for asking!'
          }
        )
      end
    end

    context 'with custom model parameter' do
      it 'creates a run with specified model' do
        custom_model = 'gemini-1.5-flash-8b'
        result = runs.create(thread_id: thread_id, parameters: { model: custom_model })

        expect(result['model']).to eq(custom_model)
        
        # Verify chat was called with appropriate parameters
        expect(client).to have_received(:chat).with(
          parameters: hash_including(model: custom_model)
        )
      end
    end

    context 'with metadata' do
      it 'creates a run with metadata' do
        metadata = { 'purpose' => 'testing' }
        result = runs.create(thread_id: thread_id, parameters: { metadata: metadata })

        expect(result['metadata']).to eq(metadata)
      end
    end

    context 'with non-existent thread ID' do
      it 'raises an error' do
        invalid_thread_id = 'invalid-thread'
        allow(threads).to receive(:retrieve).with(id: invalid_thread_id)
          .and_raise(Gemini::Error.new('Thread not found', 'thread_not_found'))

        expect {
          runs.create(thread_id: invalid_thread_id)
        }.to raise_error(Gemini::Error, 'Thread not found')
      end
    end

    context 'when API response has no candidates' do
      it 'creates a run with no response' do
        allow(client).to receive(:chat).and_return({ 'candidates' => [] })
        
        result = runs.create(thread_id: thread_id)
        
        expect(result['status']).to eq('completed')
        # Verify message creation was not called
        expect(messages).not_to have_received(:create).with(
          hash_including(role: 'model')
        )
      end
    end
  end

  describe '#retrieve' do
    before do
      # Create a run first
      runs.create(thread_id: thread_id)
    end

    context 'with existing run' do
      it 'retrieves run information' do
        result = runs.retrieve(thread_id: thread_id, id: run_id)

        expect(result).to include(
          'id' => run_id,
          'thread_id' => thread_id,
          'status' => 'completed'
        )
        
        # Verify response field is not included
        expect(result).not_to have_key('response')
      end
    end

    context 'with non-existent run ID' do
      it 'raises an error' do
        expect {
          runs.retrieve(thread_id: thread_id, id: 'non-existent-id')
        }.to raise_error(Gemini::Error, 'Run not found')
      end
    end

    context 'when retrieving with different thread ID' do
      it 'raises an error' do
        expect {
          runs.retrieve(thread_id: 'different-thread-id', id: run_id)
        }.to raise_error(Gemini::Error, 'Run does not belong to thread')
      end
    end
  end
end