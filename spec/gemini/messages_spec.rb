require 'spec_helper'
require 'time'

RSpec.describe Gemini::Messages do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:threads) { instance_double('Gemini::Threads') }
  let(:messages) { Gemini::Messages.new(client: client) }
  let(:thread_id) { 'test-thread-id' }
  let(:message_id) { 'test-message-id' }

  before do
    allow(client).to receive(:threads).and_return(threads)
    # Assume thread exists by default
    allow(threads).to receive(:retrieve).with(id: thread_id).and_return({ 'id' => thread_id })
    allow(SecureRandom).to receive(:uuid).and_return(message_id)
    allow(Time).to receive(:now).and_return(Time.at(1234567890))
  end

  describe '#create' do
    context 'with valid thread ID and parameters' do
      it 'creates and returns a new message' do
        result = messages.create(
          thread_id: thread_id,
          parameters: {
            role: 'user',
            content: 'Hello, world!'
          }
        )

        expect(result).to include(
          'id' => message_id,
          'object' => 'thread.message',
          'created_at' => 1234567890,
          'thread_id' => thread_id,
          'role' => 'user'
        )

        # Check content formatting is correct
        expect(result['content']).to be_an(Array)
        expect(result['content'].first).to include(
          'type' => 'text',
          'text' => { 'value' => 'Hello, world!' }
        )
      end
    end

    context 'using default role' do
      it 'creates a message with default role (user)' do
        result = messages.create(
          thread_id: thread_id,
          parameters: {
            content: 'Hello, world!'
          }
        )

        expect(result['role']).to eq('user')
      end
    end

    context 'with array content' do
      it 'creates a message with multiple text items' do
        content = ['Hello', 'world']
        result = messages.create(
          thread_id: thread_id,
          parameters: {
            content: content
          }
        )

        expect(result['content'].length).to eq(2)
        expect(result['content'][0]['text']['value']).to eq('Hello')
        expect(result['content'][1]['text']['value']).to eq('world')
      end
    end

    context 'with non-existent thread ID' do
      it 'raises an error' do
        invalid_thread_id = 'invalid-thread'
        allow(threads).to receive(:retrieve).with(id: invalid_thread_id)
          .and_raise(Gemini::Error.new('Thread not found', 'thread_not_found'))

        expect {
          messages.create(thread_id: invalid_thread_id, parameters: { content: 'Test' })
        }.to raise_error(Gemini::Error, 'Thread not found')
      end
    end
  end

  describe '#list' do
    context 'when messages exist' do
      before do
        # Add messages to thread
        messages.create(
          thread_id: thread_id,
          parameters: { content: 'Message 1' }
        )
        allow(SecureRandom).to receive(:uuid).and_return('message-id-2')
        messages.create(
          thread_id: thread_id,
          parameters: { content: 'Message 2' }
        )
      end

      it 'lists all messages in the thread' do
        result = messages.list(thread_id: thread_id)

        expect(result['object']).to eq('list')
        expect(result['data'].length).to eq(2)
        expect(result['first_id']).to eq(message_id)
        expect(result['last_id']).to eq('message-id-2')
        expect(result['has_more']).to be false
      end
    end

    context 'when no messages exist' do
      it 'returns an empty list' do
        result = messages.list(thread_id: thread_id)

        expect(result['object']).to eq('list')
        expect(result['data']).to be_empty
        expect(result['first_id']).to be_nil
        expect(result['last_id']).to be_nil
        expect(result['has_more']).to be false
      end
    end

    context 'with non-existent thread ID' do
      it 'raises an error' do
        invalid_thread_id = 'invalid-thread'
        allow(threads).to receive(:retrieve).with(id: invalid_thread_id)
          .and_raise(Gemini::Error.new('Thread not found', 'thread_not_found'))

        expect {
          messages.list(thread_id: invalid_thread_id)
        }.to raise_error(Gemini::Error, 'Thread not found')
      end
    end
  end

  describe '#retrieve' do
    context 'with existing message' do
      before do
        messages.create(
          thread_id: thread_id,
          parameters: { content: 'Test message' }
        )
      end

      it 'retrieves the message' do
        result = messages.retrieve(thread_id: thread_id, id: message_id)

        expect(result).to include(
          'id' => message_id,
          'thread_id' => thread_id
        )
        expect(result['content'].first['text']['value']).to eq('Test message')
      end
    end

    context 'with non-existent message' do
      it 'raises an error' do
        expect {
          messages.retrieve(thread_id: thread_id, id: 'non-existent-id')
        }.to raise_error(Gemini::Error, 'Message not found')
      end
    end
  end

  describe '#modify' do
    let(:metadata) { { 'tag' => 'important' } }

    before do
      messages.create(
        thread_id: thread_id,
        parameters: { content: 'Original message' }
      )
    end

    it 'updates message metadata' do
      result = messages.modify(
        thread_id: thread_id,
        id: message_id,
        parameters: { metadata: metadata }
      )

      expect(result['metadata']).to eq(metadata)
      # Verify metadata was actually saved
      retrieved = messages.retrieve(thread_id: thread_id, id: message_id)
      expect(retrieved['metadata']).to eq(metadata)
    end

    context 'with non-existent message' do
      it 'raises an error' do
        expect {
          messages.modify(
            thread_id: thread_id,
            id: 'non-existent-id',
            parameters: { metadata: metadata }
          )
        }.to raise_error(Gemini::Error, 'Message not found')
      end
    end
  end

  describe '#delete' do
    before do
      messages.create(
        thread_id: thread_id,
        parameters: { content: 'Message to delete' }
      )
    end

    it 'logically deletes the message' do
      result = messages.delete(thread_id: thread_id, id: message_id)

      expect(result).to include(
        'id' => message_id,
        'object' => 'thread.message.deleted',
        'deleted' => true
      )

      # Verify deleted message doesn't appear in list
      list_result = messages.list(thread_id: thread_id)
      expect(list_result['data']).to be_empty
    end

    context 'with non-existent message' do
      it 'raises an error' do
        expect {
          messages.delete(thread_id: thread_id, id: 'non-existent-id')
        }.to raise_error(Gemini::Error, 'Message not found')
      end
    end
  end

  describe '#format_content' do
    # Helper method to test private method
    def format_content(content)
      messages.send(:format_content, content)
    end

    context 'with string input' do
      it 'formats to proper structure' do
        result = format_content('Simple text')
        
        expect(result).to eq([{ 'type' => 'text', 'text' => { 'value' => 'Simple text' } }])
      end
    end

    context 'with array input' do
      it 'formats each item to proper structure' do
        result = format_content(['Item 1', 'Item 2'])
        
        expect(result).to eq([
          { 'type' => 'text', 'text' => { 'value' => 'Item 1' } },
          { 'type' => 'text', 'text' => { 'value' => 'Item 2' } }
        ])
      end
    end

    context 'with hash input' do
      it 'wraps hash in an array' do
        content = { 'type' => 'text', 'text' => { 'value' => 'Hash content' } }
        result = format_content(content)
        
        expect(result).to eq([content])
      end
    end

    context 'with other object types' do
      it 'converts to string and formats' do
        result = format_content(123)
        
        expect(result).to eq([{ 'type' => 'text', 'text' => { 'value' => '123' } }])
      end
    end
  end
end