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
    
    # スレッドの存在確認メソッド
    allow(threads).to receive(:retrieve).with(id: thread_id).and_return({ 'id' => thread_id })
    
    # スレッドのモデル取得メソッド
    allow(threads).to receive(:get_model).with(id: thread_id).and_return('gemini-2.0-flash-lite')
    
    # メッセージ一覧取得のモック
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
    
    # チャットレスポンスのモック
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
    
    # メッセージ作成のモック
    allow(messages).to receive(:create).and_return({
      'id' => 'response-message-id',
      'role' => 'model',
      'content' => [
        { 'type' => 'text', 'text' => { 'value' => 'I am fine, thank you for asking!' } }
      ]
    })
  end

  describe '#create' do
    context '有効なスレッドIDでの実行' do
      it '新しい実行を作成して結果を返す' do
        result = runs.create(thread_id: thread_id)

        expect(result).to include(
          'id' => run_id,
          'object' => 'thread.run',
          'created_at' => 1234567890,
          'thread_id' => thread_id,
          'status' => 'completed',
          'model' => 'gemini-2.0-flash-lite'
        )
        
        # メッセージが作成されたことを確認
        expect(messages).to have_received(:create).with(
          thread_id: thread_id,
          parameters: {
            role: 'model',
            content: 'I am fine, thank you for asking!'
          }
        )
      end
    end

    context 'カスタムモデルパラメータでの実行' do
      it '指定されたモデルで実行を作成する' do
        custom_model = 'gemini-1.5-flash-8b'
        result = runs.create(thread_id: thread_id, parameters: { model: custom_model })

        expect(result['model']).to eq(custom_model)
        
        # 適切なパラメータでchat呼び出しが行われたことを確認
        expect(client).to have_received(:chat).with(
          parameters: hash_including(model: custom_model)
        )
      end
    end

    context 'メタデータを含む実行' do
      it 'メタデータ付きで実行を作成する' do
        metadata = { 'purpose' => 'testing' }
        result = runs.create(thread_id: thread_id, parameters: { metadata: metadata })

        expect(result['metadata']).to eq(metadata)
      end
    end

    context '存在しないスレッドIDの場合' do
      it 'エラーを発生させる' do
        invalid_thread_id = 'invalid-thread'
        allow(threads).to receive(:retrieve).with(id: invalid_thread_id)
          .and_raise(Gemini::Error.new('Thread not found', 'thread_not_found'))

        expect {
          runs.create(thread_id: invalid_thread_id)
        }.to raise_error(Gemini::Error, 'Thread not found')
      end
    end

    context 'APIレスポンスにcandidatesがない場合' do
      it '応答のないランを作成する' do
        allow(client).to receive(:chat).and_return({ 'candidates' => [] })
        
        result = runs.create(thread_id: thread_id)
        
        expect(result['status']).to eq('completed')
        # メッセージ作成が呼ばれないことを確認
        expect(messages).not_to have_received(:create).with(
          hash_including(role: 'model')
        )
      end
    end
  end

  describe '#retrieve' do
    before do
      # 事前に実行を作成
      runs.create(thread_id: thread_id)
    end

    context '存在する実行の場合' do
      it '実行情報を取得する' do
        result = runs.retrieve(thread_id: thread_id, id: run_id)

        expect(result).to include(
          'id' => run_id,
          'thread_id' => thread_id,
          'status' => 'completed'
        )
        
        # レスポンスフィールドが含まれていないことを確認
        expect(result).not_to have_key('response')
      end
    end

    context '存在しない実行IDの場合' do
      it 'エラーを発生させる' do
        expect {
          runs.retrieve(thread_id: thread_id, id: 'non-existent-id')
        }.to raise_error(Gemini::Error, 'Run not found')
      end
    end

    context '異なるスレッドIDでの取得の場合' do
      it 'エラーを発生させる' do
        expect {
          runs.retrieve(thread_id: 'different-thread-id', id: run_id)
        }.to raise_error(Gemini::Error, 'Run does not belong to thread')
      end
    end
  end
end