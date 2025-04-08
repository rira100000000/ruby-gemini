require 'spec_helper'

RSpec.describe Gemini::Audio do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:audio) { Gemini::Audio.new(client: client) }
  
  describe '#transcribe' do
    let(:test_audio_file) { instance_double('File') }
    let(:file_path) { '/path/to/audio.mp3' }
    let(:response_data) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "これはテスト音声の文字起こし結果です。" }
              ]
            }
          }
        ]
      }
    end

    before do
      allow(test_audio_file).to receive(:path).and_return(file_path)
      allow(test_audio_file).to receive(:rewind)
      allow(test_audio_file).to receive(:read).and_return('テスト音声データ')
      allow(test_audio_file).to receive(:close)
      allow(File).to receive(:extname).with(file_path).and_return('.mp3')
      
      # Base64エンコードをモック
      require 'base64'
      allow(Base64).to receive(:strict_encode64).with('テスト音声データ').and_return('encoded_audio_data')
      
      # クライアントのjson_postメソッドをモック
      allow(client).to receive(:json_post).and_return(response_data)
    end

    context '基本的な文字起こし' do
      it '正しいパラメータでAPIリクエストを送信する' do
        audio.transcribe(parameters: { file: test_audio_file })
        
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/gemini-1.5-flash:generateContent")
          
          # コンテンツ構造の検証
          contents = args[:parameters][:contents]
          expect(contents).to be_an(Array)
          expect(contents.size).to eq(1)
          
          # パーツの検証
          parts = contents[0][:parts]
          expect(parts).to be_an(Array)
          expect(parts.size).to eq(2)
          
          # テキスト部分の検証
          expect(parts[0][:text]).to eq("Transcribe this audio clip")
          
          # インラインデータ部分の検証
          inline_data = parts[1][:inline_data]
          expect(inline_data[:mime_type]).to eq("audio/mp3")
          expect(inline_data[:data]).to eq("encoded_audio_data")
        end
      end

      it '正しい形式でレスポンスを返す' do
        result = audio.transcribe(parameters: { file: test_audio_file })
        
        expect(result).to include(
          "text" => "これはテスト音声の文字起こし結果です。",
          "raw_response" => response_data
        )
      end
    end

    context 'カスタムモデルを指定' do
      it '指定されたモデルを使用する' do
        custom_model = "gemini-2.0-pro"
        
        audio.transcribe(parameters: { file: test_audio_file, model: custom_model })
        
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/#{custom_model}:generateContent")
        end
      end
    end

    context '言語指定あり' do
      # バグ修正後の正しい挙動をテスト
      it '言語指定を含むプロンプトを生成する' do
        language = "ja"
        expected_text = "Transcribe this audio clip in #{language}"
        
        audio.transcribe(parameters: { file: test_audio_file, language: language })
        
        expect(client).to have_received(:json_post) do |args|
          text_part = args[:parameters][:contents][0][:parts][0]
          expect(text_part[:text]).to eq(expected_text)
        end
      end
    end

    context 'カスタムプロンプトテキスト' do
      it 'カスタムプロンプトテキストを使用する' do
        custom_text = "この音声を日本語で文字起こししてください"
        
        audio.transcribe(parameters: { file: test_audio_file, content_text: custom_text })
        
        expect(client).to have_received(:json_post) do |args|
          text_part = args[:parameters][:contents][0][:parts][0]
          expect(text_part[:text]).to eq(custom_text)
        end
      end
      
      it 'カスタムプロンプトと言語指定を組み合わせる' do
        custom_text = "この音声を文字起こししてください"
        language = "ja"
        expected_text = "#{custom_text} in #{language}"
        
        audio.transcribe(parameters: { 
          file: test_audio_file, 
          content_text: custom_text,
          language: language
        })
        
        expect(client).to have_received(:json_post) do |args|
          text_part = args[:parameters][:contents][0][:parts][0]
          expect(text_part[:text]).to eq(expected_text)
        end
      end
    end

    context '追加パラメータあり' do
      it '追加パラメータをリクエストに含める' do
        audio.transcribe(parameters: { 
          file: test_audio_file,
          max_tokens: 1000,
          temperature: 0.2
        })
        
        expect(client).to have_received(:json_post) do |args|
          params = args[:parameters]
          expect(params[:max_tokens]).to eq(1000)
          expect(params[:temperature]).to eq(0.2)
        end
      end
    end

    context 'ファイルが指定されていない場合' do
      it 'ArgumentErrorを発生させる' do
        expect {
          audio.transcribe(parameters: {})
        }.to raise_error(ArgumentError, "音声ファイルが指定されていません")
      end
    end

    context '異なるファイル拡張子での呼び出し' do
      # 各ファイル拡張子ごとに個別のテストを実行
      {
        '.wav' => 'audio/wav',
        '.mp3' => 'audio/mp3',
        '.aiff' => 'audio/aiff',
        '.aac' => 'audio/aac',
        '.ogg' => 'audio/ogg',
        '.flac' => 'audio/flac',
        '.unknown' => 'audio/mp3' # デフォルト値
      }.each do |ext, mime_type|
        it "#{ext} ファイルに対して #{mime_type} を使用する" do
          # 各テストごとにモックをリセット
          allow(client).to receive(:json_post).and_return(response_data)
          allow(File).to receive(:extname).with(file_path).and_return(ext)
          
          audio.transcribe(parameters: { file: test_audio_file })
          
          expect(client).to have_received(:json_post) do |args|
            inline_data = args[:parameters][:contents][0][:parts][1][:inline_data]
            expect(inline_data[:mime_type]).to eq(mime_type)
          end
        end
      end
    end

    context 'レスポンスに候補がない場合' do
      let(:empty_response) { { "candidates" => [] } }
      
      before do
        allow(client).to receive(:json_post).and_return(empty_response)
      end
      
      it '空のテキストを含む応答を返す' do
        result = audio.transcribe(parameters: { file: test_audio_file })
        
        expect(result).to eq({
          "text" => "",
          "raw_response" => empty_response
        })
      end
    end
  end
end