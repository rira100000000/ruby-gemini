require 'spec_helper'
require 'time'

RSpec.describe Gemini::Threads do
  let(:api_key) { 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:threads) { Gemini::Threads.new(client: client) }

  describe '#create' do
    context '基本パラメータのみで作成' do
      it 'スレッドを作成しIDを返す' do
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

    context 'メタデータを指定して作成' do
      it 'メタデータ付きでスレッドを作成する' do
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

    context 'モデルを指定して作成' do
      it '指定したモデルでスレッドを作成する' do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        
        result = threads.create(parameters: { model: 'gemini-2.0-pro' })
        
        # 直接返り値にはモデル情報が含まれないため、内部状態を確認
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-pro')
      end
    end
  end

  describe '#retrieve' do
    context '存在するスレッドの場合' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('test-thread-id')
        allow(Time).to receive(:now).and_return(Time.at(1234567890))
        threads.create
      end

      it 'スレッド情報を取得する' do
        result = threads.retrieve(id: 'test-thread-id')

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890,
          'metadata' => {}
        )
      end
    end

    context '存在しないスレッドの場合' do
      it 'エラーを発生させる' do
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

    context 'メタデータを変更' do
      it 'スレッドのメタデータを更新する' do
        new_metadata = { 'user_id' => '456', 'priority' => 'high' }
        result = threads.modify(id: 'test-thread-id', parameters: { metadata: new_metadata })

        expect(result['metadata']).to eq(new_metadata)
        # 他の属性は変更されていないことを確認
        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread',
          'created_at' => 1234567890
        )
      end
    end

    context 'モデルを変更' do
      it 'スレッドのモデルを更新する' do
        threads.modify(id: 'test-thread-id', parameters: { model: 'gemini-2.0-pro' })
        
        # get_modelメソッドで内部状態を確認
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-pro')
      end
    end

    context '存在しないスレッドの場合' do
      it 'エラーを発生させる' do
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

    context '存在するスレッドの場合' do
      it 'スレッドを削除する' do
        result = threads.delete(id: 'test-thread-id')

        expect(result).to include(
          'id' => 'test-thread-id',
          'object' => 'thread.deleted',
          'deleted' => true
        )

        # 削除後にアクセスするとエラーが発生することを確認
        expect {
          threads.retrieve(id: 'test-thread-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end

    context '存在しないスレッドの場合' do
      it 'エラーを発生させる' do
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

    context '存在するスレッドの場合' do
      it 'スレッドのモデルを取得する' do
        expect(threads.get_model(id: 'test-thread-id')).to eq('gemini-2.0-flash-lite')
      end
    end

    context '存在しないスレッドの場合' do
      it 'エラーを発生させる' do
        expect {
          threads.get_model(id: 'non-existent-id')
        }.to raise_error(Gemini::Error, "Thread not found")
      end
    end
  end
end