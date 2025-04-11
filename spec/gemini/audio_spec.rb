require 'spec_helper'

RSpec.describe Gemini::Audio do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:audio) { Gemini::Audio.new(client: client) }
  let(:response_instance) { instance_double('Gemini::Response') }
  
  describe '#transcribe' do
    let(:test_audio_file) { instance_double('File') }
    let(:file_path) { '/path/to/audio.mp3' }
    let(:api_response_data) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "This is a test transcription result." }
              ]
            }
          }
        ]
      }
    end
    
    let(:formatted_response) do
      {
        "text" => "This is a test transcription result.",
        "raw_response" => api_response_data
      }
    end

    before do
      allow(test_audio_file).to receive(:path).and_return(file_path)
      allow(test_audio_file).to receive(:rewind)
      allow(test_audio_file).to receive(:read).and_return('Test audio data')
      allow(test_audio_file).to receive(:close)
      allow(File).to receive(:extname).with(file_path).and_return('.mp3')
      
      # Mock Base64 encoding
      require 'base64'
      allow(Base64).to receive(:strict_encode64).with('Test audio data').and_return('encoded_audio_data')
      
      # Mock client's json_post method
      allow(client).to receive(:json_post).and_return(api_response_data)
      
      # Mock Response class
      allow(Gemini::Response).to receive(:new).with(formatted_response).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("This is a test transcription result.")
      allow(response_instance).to receive(:raw_data).and_return(formatted_response)
    end

    context 'basic transcription' do
      it 'sends API request with correct parameters' do
        audio.transcribe(parameters: { file: test_audio_file })
        
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/gemini-1.5-flash:generateContent")
          
          # Verify content structure
          contents = args[:parameters][:contents]
          expect(contents).to be_an(Array)
          expect(contents.size).to eq(1)
          
          # Verify parts
          parts = contents[0][:parts]
          expect(parts).to be_an(Array)
          expect(parts.size).to eq(2)
          
          # Verify text part
          expect(parts[0][:text]).to eq("Transcribe this audio clip")
          
          # Verify inline data part
          inline_data = parts[1][:inline_data]
          expect(inline_data[:mime_type]).to eq("audio/mp3")
          expect(inline_data[:data]).to eq("encoded_audio_data")
        end
      end

      it 'returns Response object with transcription text' do
        result = audio.transcribe(parameters: { file: test_audio_file })
        
        expect(result).to be(response_instance)
        expect(result.text).to eq("This is a test transcription result.")
      end
    end

    context 'with custom model specified' do
      it 'uses the specified model' do
        custom_model = "gemini-2.0-pro"
        
        audio.transcribe(parameters: { file: test_audio_file, model: custom_model })
        
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/#{custom_model}:generateContent")
        end
      end
    end

    context 'with language specified' do
      # Test correct behavior after bug fix
      it 'generates prompt with language instruction' do
        language = "ja"
        expected_text = "Transcribe this audio clip in #{language}"
        
        audio.transcribe(parameters: { file: test_audio_file, language: language })
        
        expect(client).to have_received(:json_post) do |args|
          text_part = args[:parameters][:contents][0][:parts][0]
          expect(text_part[:text]).to eq(expected_text)
        end
      end
    end

    context 'with custom prompt text' do
      it 'uses custom prompt text' do
        custom_text = "Please transcribe this audio in Japanese"
        
        audio.transcribe(parameters: { file: test_audio_file, content_text: custom_text })
        
        expect(client).to have_received(:json_post) do |args|
          text_part = args[:parameters][:contents][0][:parts][0]
          expect(text_part[:text]).to eq(custom_text)
        end
      end
      
      it 'combines custom prompt and language specification' do
        custom_text = "Please transcribe this audio"
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

    context 'with additional parameters' do
      it 'includes additional parameters in request' do
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

    context 'with file_uri instead of file' do
      let(:file_uri) { "files/audio123" }

      before do
        allow(audio).to receive(:transcribe_with_file_uri).and_call_original
      end
      
      it 'calls transcribe_with_file_uri and returns Response object' do
        result = audio.transcribe(parameters: { file_uri: file_uri })
        
        expect(result).to be(response_instance)
        expect(client).to have_received(:json_post) do |args|
          expect(args[:path]).to eq("models/gemini-1.5-flash:generateContent")
          
          # Verify content structure
          contents = args[:parameters][:contents]
          expect(contents[0][:parts][1][:file_data][:file_uri]).to eq(file_uri)
          expect(contents[0][:parts][1][:file_data][:mime_type]).to eq("audio/mp3")
        end
      end
    end

    context 'with no file specified' do
      it 'raises ArgumentError' do
        expect {
          audio.transcribe(parameters: {})
        }.to raise_error(ArgumentError, "No audio file specified")
      end
    end

    context 'with different file extensions' do
      # Test each file extension individually
      {
        '.wav' => 'audio/wav',
        '.mp3' => 'audio/mp3',
        '.aiff' => 'audio/aiff',
        '.aac' => 'audio/aac',
        '.ogg' => 'audio/ogg',
        '.flac' => 'audio/flac',
        '.unknown' => 'audio/mp3' # Default value
      }.each do |ext, mime_type|
        it "uses #{mime_type} for #{ext} files" do
          # Reset mocks for each test
          allow(client).to receive(:json_post).and_return(api_response_data)
          allow(File).to receive(:extname).with(file_path).and_return(ext)
          
          audio.transcribe(parameters: { file: test_audio_file })
          
          expect(client).to have_received(:json_post) do |args|
            inline_data = args[:parameters][:contents][0][:parts][1][:inline_data]
            expect(inline_data[:mime_type]).to eq(mime_type)
          end
        end
      end
    end

    context 'when response has no candidates' do
      let(:empty_api_response) { { "candidates" => [] } }
      let(:empty_formatted_response) { { "text" => "", "raw_response" => empty_api_response } }
      
      before do
        allow(client).to receive(:json_post).and_return(empty_api_response)
        allow(Gemini::Response).to receive(:new).with(empty_formatted_response).and_return(response_instance)
        allow(response_instance).to receive(:text).and_return("")
      end
      
      it 'returns Response object with empty text' do
        result = audio.transcribe(parameters: { file: test_audio_file })
        
        expect(result).to be(response_instance)
        expect(result.text).to eq("")
      end
    end
  end
end