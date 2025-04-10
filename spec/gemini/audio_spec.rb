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

    context 'ファイルを直接アップロードする場合' do
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

    context 'File APIを使用する場合（file_uriを指定）' do
      let(:file_uri) { "gemini://12345" }
      
      before do
        allow(client).to receive(:json_post).and_return(response_data)
      end

      it '正しいパラメータでAPIリクエストを送信する' do
        audio.transcribe(parameters: { file_uri: file_uri, language: "ja" })
        
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
          expect(parts[0][:text]).to eq("Transcribe this audio clip in ja")
          
          # file_data部分の検証
          file_data = parts[1][:file_data]
          expect(file_data[:mime_type]).to eq("audio/mp3")
          expect(file_data[:file_uri]).to eq(file_uri)
        end
      end

      it '正しい形式でレスポンスを返す' do
        result = audio.transcribe(parameters: { file_uri: file_uri })
        
        expect(result).to include(
          "text" => "これはテスト音声の文字起こし結果です。",
          "raw_response" => response_data
        )
      end
      
      context 'カスタムモデルとプロンプトを指定' do
        it '指定されたモデルとプロンプトを使用する' do
          custom_model = "gemini-2.0-pro"
          custom_text = "この音声を文字起こししてください"
          
          audio.transcribe(parameters: { 
            file_uri: file_uri, 
            model: custom_model,
            content_text: custom_text,
            language: "ja"
          })
          
          expect(client).to have_received(:json_post) do |args|
            expect(args[:path]).to eq("models/#{custom_model}:generateContent")
            text_part = args[:parameters][:contents][0][:parts][0]
            expect(text_part[:text]).to eq("#{custom_text} in ja")
          end
        end
      end
    end

    context 'ファイルもfile_uriも指定されていない場合' do
      it 'ArgumentErrorを発生させる' do
        expect {
          audio.transcribe(parameters: {})
        }.to raise_error(ArgumentError, "音声ファイル（file）またはファイルURI（file_uri）が指定されていません")
      end
    end
  end
end