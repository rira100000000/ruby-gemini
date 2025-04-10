require 'spec_helper'

RSpec.describe Gemini::Files do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:conn) { instance_double('Faraday::Connection') }
  let(:files) { Gemini::Files.new(client: client) }
  let(:file_name) { 'files/test-file-123' }
  
  before do
    allow(client).to receive(:api_key).and_return(api_key)
    allow(client).to receive(:uri_base).and_return('https://generativelanguage.googleapis.com/v1beta')
    allow(client).to receive(:conn).and_return(conn)
    allow(client).to receive(:get)
    allow(client).to receive(:delete)
    allow(client).to receive(:headers).and_return({ 'Content-Type' => 'application/json' })
  end

  describe '#upload' do
    let(:test_file) { instance_double('File') }
    let(:file_path) { '/path/to/file.mp3' }
    let(:file_size) { 1024 }
    let(:file_data) { 'Test file data' }
    let(:upload_url) { 'https://upload-url.example.com' }
    let(:initial_response) { instance_double('Faraday::Response') }
    let(:upload_response) { instance_double('Faraday::Response') }
    let(:response_body) { '{"file":{"uri":"file-uri","name":"files/123"}}' }
    let(:parsed_response) { { 'file' => { 'uri' => 'file-uri', 'name' => 'files/123' } } }
    
    before do
      allow(test_file).to receive(:path).and_return(file_path)
      allow(test_file).to receive(:rewind)
      allow(test_file).to receive(:size).and_return(file_size)
      allow(test_file).to receive(:read).and_return(file_data)
      
      allow(File).to receive(:basename).with(file_path).and_return('file.mp3')
      allow(File).to receive(:extname).with(file_path).and_return('.mp3')
      
      allow(initial_response).to receive(:headers).and_return({ 'x-goog-upload-url' => upload_url })
      allow(upload_response).to receive(:body).and_return(response_body)
      
      allow(conn).to receive(:post).and_return(initial_response, upload_response)
      
      # Mock JSON.parse
      allow(JSON).to receive(:parse).with(response_body).and_return(parsed_response)
    end

    it 'initializes request with appropriate headers' do
      files.upload(file: test_file)
      
      expect(conn).to have_received(:post).with("https://generativelanguage.googleapis.com/upload/v1beta/files") do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:headers).and_return({})
        allow(req).to receive(:params=)
        allow(req).to receive(:body=)
        
        block.call(req)
        
        expect(req).to have_received(:headers=) do |headers|
          expect(headers).to include(
            "X-Goog-Upload-Protocol" => "resumable",
            "X-Goog-Upload-Command" => "start",
            "X-Goog-Upload-Header-Content-Length" => file_size.to_s,
            "X-Goog-Upload-Header-Content-Type" => "audio/mp3"
          )
        end
        
        expect(req).to have_received(:params=).with({ key: api_key })
        expect(req).to have_received(:body=).with({ file: { display_name: 'file.mp3' } }.to_json)
      end
    end

    it 'uploads file data to the upload URL' do
      files.upload(file: test_file)
      
      expect(conn).to have_received(:post).with(upload_url) do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:body=)
        
        block.call(req)
        
        expect(req).to have_received(:headers=).with(
          "Content-Length" => file_size.to_s,
          "X-Goog-Upload-Offset" => "0",
          "X-Goog-Upload-Command" => "upload, finalize"
        )
        
        expect(req).to have_received(:body=).with(file_data)
      end
    end

    it 'returns parsed response' do
      result = files.upload(file: test_file)
      
      # Using JSON.parse instead of client.parse_json
      expect(JSON).to have_received(:parse).with(response_body)
      expect(result).to eq(parsed_response)
    end
    
    context 'when no file is specified' do
      it 'raises ArgumentError' do
        expect { 
          files.upload(file: nil) 
        }.to raise_error(ArgumentError, "No file specified")
      end
    end

    context 'when upload URL cannot be obtained' do
      before do
        allow(initial_response).to receive(:headers).and_return({})
      end

      it 'raises an error' do
        expect { 
          files.upload(file: test_file) 
        }.to raise_error("Failed to obtain upload URL")
      end
    end
  end

  describe '#get' do
    let(:file_metadata) { { 'name' => file_name, 'uri' => 'file-uri', 'mimeType' => 'audio/mp3' } }
    
    before do
      allow(client).to receive(:get).with(path: file_name).and_return(file_metadata)
    end

    it 'retrieves file metadata' do
      result = files.get(name: file_name)
      
      expect(client).to have_received(:get).with(path: file_name)
      expect(result).to eq(file_metadata)
    end

    context 'when file name without files/ prefix is provided' do
      it 'adds files/ prefix' do
        files.get(name: 'test-file-123')
        
        expect(client).to have_received(:get).with(path: file_name)
      end
    end
  end

  describe '#list' do
    let(:file_list) { { 'files' => [{ 'name' => 'files/1' }, { 'name' => 'files/2' }] } }
    
    before do
      allow(client).to receive(:get).with(
        path: 'files',
        parameters: {}
      ).and_return(file_list)
    end

    it 'retrieves file list' do
      result = files.list
      
      expect(client).to have_received(:get).with(path: 'files', parameters: {})
      expect(result).to eq(file_list)
    end

    context 'when pagination parameters are specified' do
      let(:pagination_params) { { pageSize: 5, pageToken: 'next-token' } }
      
      before do
        allow(client).to receive(:get).with(
          path: 'files',
          parameters: pagination_params
        ).and_return(file_list.merge({ 'nextPageToken' => 'another-token' }))
      end

      it 'makes request with specified parameters' do
        result = files.list(page_size: 5, page_token: 'next-token')
        
        expect(client).to have_received(:get).with(path: 'files', parameters: pagination_params)
        expect(result).to include('nextPageToken' => 'another-token')
      end
    end
  end

  describe '#delete' do
    let(:delete_result) { {} }
    
    before do
      allow(client).to receive(:delete).with(path: file_name).and_return(delete_result)
    end

    it 'deletes the file' do
      result = files.delete(name: file_name)
      
      expect(client).to have_received(:delete).with(path: file_name)
      expect(result).to eq(delete_result)
    end

    context 'when file name without files/ prefix is provided' do
      it 'adds files/ prefix' do
        files.delete(name: 'test-file-123')
        
        expect(client).to have_received(:delete).with(path: file_name)
      end
    end
  end
end