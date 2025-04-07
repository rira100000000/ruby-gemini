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
    # スレッドがデフォルトでは存在するという想定
    allow(threads).to receive(:retrieve).with(id: thread_id).and_return({ 'id' => thread_id })
    allow(SecureRandom).to receive(:uuid).and_return(message_id)
    allow(Time).to receive(:now).and_return(Time.at(1234567890))
  end

  describe '#create' do
    context '有効なスレッドIDとパラメータで作成' do
      it '新しいメッセージを作成して返す' do
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

        # コンテンツのフォーマットが正しいか確認
        expect(result['content']).to be_an(Array)
        expect(result['content'].first).to include(
          'type' => 'text',
          'text' => { 'value' => 'Hello, world!' }
        )
      end
    end

    context 'デフォルトロールを使用' do
      it 'デフォルトロール（user）でメッセージを作成する' do
        result = messages.create(
          thread_id: thread_id,
          parameters: {
            content: 'Hello, world!'
          }
        )

        expect(result['role']).to eq('user')
      end
    end

    context '配列コンテンツでの作成' do
      it '複数のテキストアイテムを含むメッセージを作成する' do
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

    context '存在しないスレッドIDの場合' do
      it 'エラーを発生させる' do
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
    context 'メッセージが存在する場合' do
      before do
        # スレッドにメッセージを追加
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

      it 'スレッド内の全メッセージをリストアップする' do
        result = messages.list(thread_id: thread_id)

        expect(result['object']).to eq('list')
        expect(result['data'].length).to eq(2)
        expect(result['first_id']).to eq(message_id)
        expect(result['last_id']).to eq('message-id-2')
        expect(result['has_more']).to be false
      end
    end

    context 'メッセージが存在しない場合' do
      it '空のリストを返す' do
        result = messages.list(thread_id: thread_id)

        expect(result['object']).to eq('list')
        expect(result['data']).to be_empty
        expect(result['first_id']).to be_nil
        expect(result['last_id']).to be_nil
        expect(result['has_more']).to be false
      end
    end

    context '存在しないスレッドIDの場合' do
      it 'エラーを発生させる' do
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
    context '存在するメッセージの場合' do
      before do
        messages.create(
          thread_id: thread_id,
          parameters: { content: 'Test message' }
        )
      end

      it 'メッセージを取得する' do
        result = messages.retrieve(thread_id: thread_id, id: message_id)

        expect(result).to include(
          'id' => message_id,
          'thread_id' => thread_id
        )
        expect(result['content'].first['text']['value']).to eq('Test message')
      end
    end

    context '存在しないメッセージの場合' do
      it 'エラーを発生させる' do
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

    it 'メッセージのメタデータを更新する' do
      result = messages.modify(
        thread_id: thread_id,
        id: message_id,
        parameters: { metadata: metadata }
      )

      expect(result['metadata']).to eq(metadata)
      # メタデータが実際に保存されていることを確認
      retrieved = messages.retrieve(thread_id: thread_id, id: message_id)
      expect(retrieved['metadata']).to eq(metadata)
    end

    context '存在しないメッセージの場合' do
      it 'エラーを発生させる' do
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

    it 'メッセージを論理削除する' do
      result = messages.delete(thread_id: thread_id, id: message_id)

      expect(result).to include(
        'id' => message_id,
        'object' => 'thread.message.deleted',
        'deleted' => true
      )

      # 削除したメッセージがリストに表示されないことを確認
      list_result = messages.list(thread_id: thread_id)
      expect(list_result['data']).to be_empty
    end

    context '存在しないメッセージの場合' do
      it 'エラーを発生させる' do
        expect {
          messages.delete(thread_id: thread_id, id: 'non-existent-id')
        }.to raise_error(Gemini::Error, 'Message not found')
      end
    end
  end

  describe '#format_content' do
    # privateメソッドをテストするためのヘルパーメソッド
    def format_content(content)
      messages.send(:format_content, content)
    end

    context '文字列の場合' do
      it '適切な形式にフォーマットする' do
        result = format_content('Simple text')
        
        expect(result).to eq([{ 'type' => 'text', 'text' => { 'value' => 'Simple text' } }])
      end
    end

    context '配列の場合' do
      it '各アイテムを適切な形式にフォーマットする' do
        result = format_content(['Item 1', 'Item 2'])
        
        expect(result).to eq([
          { 'type' => 'text', 'text' => { 'value' => 'Item 1' } },
          { 'type' => 'text', 'text' => { 'value' => 'Item 2' } }
        ])
      end
    end

    context 'ハッシュの場合' do
      it 'ハッシュを配列化する' do
        content = { 'type' => 'text', 'text' => { 'value' => 'Hash content' } }
        result = format_content(content)
        
        expect(result).to eq([content])
      end
    end

    context 'その他のオブジェクトの場合' do
      it '文字列に変換してフォーマットする' do
        result = format_content(123)
        
        expect(result).to eq([{ 'type' => 'text', 'text' => { 'value' => '123' } }])
      end
    end
  end
end