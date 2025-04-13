require 'spec_helper'

RSpec.describe Gemini::CachedContent do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:files) { instance_double('Gemini::Files') }
  let(:conn) { instance_double('Faraday::Connection') }
  let(:cached_content) { Gemini::CachedContent.new(client: client) }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:response_instance) { instance_double(Gemini::Response) }
  
  before do
    allow(client).to receive(:api_key).and_return(api_key)
    allow(client).to receive(:files).and_return(files)
    allow(client).to receive(:conn).and_return(conn)
    allow(Gemini::Response).to receive(:new).and_return(response_instance)
  end

  describe '#create' do
    let(:file_path) { '/path/to/document.pdf' }
    let(:file_uri) { 'files/document-123' }
    let(:mime_type) { 'application/pdf' }
    let(:ttl) { '3600s' }
    let(:model) { 'gemini-1.5-flash' }
    let(:system_instruction) { 'You are an expert at analyzing documents.' }
    let(:file) { instance_double('File') }
    let(:upload_response) { { 'file' => { 'uri' => file_uri, 'name' => 'files/document-123' } } }
    let(:api_response) { { 'name' => 'cachedContents/cache-123', 'model' => 'models/gemini-1.5-flash' } }
    let(:faraday_response) { instance_double('Faraday::Response', body: api_response.to_json) }
    
    context 'with file_uri provided' do
      it 'creates cached content with file_uri' do
        expect(conn).to receive(:post).with('https://generativelanguage.googleapis.com/v1beta/cachedContents') do |&block|
          req = double('request')
          allow(req).to receive(:headers=)
          allow(req).to receive(:params=)
          allow(req).to receive(:body=)
          
          block.call(req)
          
          expect(req).to have_received(:params=).with(key: api_key)
          expect(req).to have_received(:body=) do |body_json|
            body = JSON.parse(body_json)
            expect(body['model']).to eq('models/gemini-1.5-flash')
            expect(body['ttl']).to eq(ttl)
            expect(body['contents'][0]['parts'][0]['file_data']['file_uri']).to eq(file_uri)
          end
          
          faraday_response
        end
        
        result = cached_content.create(file_uri: file_uri, mime_type: mime_type, ttl: ttl, model: model)
        expect(result).to eq(response_instance)
      end
      
      it 'adds system instruction when provided' do
        expect(conn).to receive(:post).with('https://generativelanguage.googleapis.com/v1beta/cachedContents') do |&block|
          req = double('request')
          allow(req).to receive(:headers=)
          allow(req).to receive(:params=)
          allow(req).to receive(:body=)
          
          block.call(req)
          
          expect(req).to have_received(:body=) do |body_json|
            body = JSON.parse(body_json)
            expect(body['systemInstruction']['parts'][0]['text']).to eq(system_instruction)
          end
          
          faraday_response
        end
        
        cached_content.create(
          file_uri: file_uri, 
          mime_type: mime_type, 
          ttl: ttl, 
          model: model,
          system_instruction: system_instruction
        )
      end
    end
    
    context 'with file_path provided' do
      before do
        allow(File).to receive(:open).with(file_path, 'rb').and_return(file)
        allow(file).to receive(:close)
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(client).to receive(:determine_mime_type).with(file_path).and_return(mime_type)
      end
      
      it 'uploads file and creates cached content with file_uri' do
        expect(conn).to receive(:post).with('https://generativelanguage.googleapis.com/v1beta/cachedContents') do |&block|
          req = double('request')
          allow(req).to receive(:headers=)
          allow(req).to receive(:params=)
          allow(req).to receive(:body=)
          
          block.call(req)
          
          expect(req).to have_received(:body=) do |body_json|
            body = JSON.parse(body_json)
            expect(body['contents'][0]['parts'][0]['file_data']['file_uri']).to eq(file_uri)
            expect(body['contents'][0]['parts'][0]['file_data']['mime_type']).to eq(mime_type)
          end
          
          faraday_response
        end
        
        result = cached_content.create(file_path: file_path, ttl: ttl, model: model)
        
        expect(File).to have_received(:open).with(file_path, 'rb')
        expect(files).to have_received(:upload).with(file: file)
        expect(file).to have_received(:close)
        expect(result).to eq(response_instance)
      end
    end
    
    context 'with neither file_path nor file_uri provided' do
      it 'raises an error' do
        expect {
          cached_content.create(model: model)
        }.to raise_error(ArgumentError, 'file_uri parameter is required')
      end
    end
    
    context 'with model prefix handling' do
      it 'adds models/ prefix to model name if missing' do
        expect(conn).to receive(:post) do |&block|
          req = double('request')
          allow(req).to receive(:headers=)
          allow(req).to receive(:params=)
          allow(req).to receive(:body=)
          
          block.call(req)
          
          expect(req).to have_received(:body=) do |body_json|
            body = JSON.parse(body_json)
            expect(body['model']).to eq('models/gemini-1.5-flash')
          end
          
          faraday_response
        end
        
        cached_content.create(file_uri: file_uri, model: 'gemini-1.5-flash')
      end
      
      it 'keeps models/ prefix if already present' do
        expect(conn).to receive(:post) do |&block|
          req = double('request')
          allow(req).to receive(:headers=)
          allow(req).to receive(:params=)
          allow(req).to receive(:body=)
          
          block.call(req)
          
          expect(req).to have_received(:body=) do |body_json|
            body = JSON.parse(body_json)
            expect(body['model']).to eq('models/gemini-1.5-flash')
          end
          
          faraday_response
        end
        
        cached_content.create(file_uri: file_uri, model: 'models/gemini-1.5-flash')
      end
    end
  end

  describe '#list' do
    let(:list_response) { { 'cachedContents' => [{ 'name' => 'cachedContents/123' }] } }
    let(:faraday_response) { instance_double('Faraday::Response', body: list_response.to_json) }
    
    it 'fetches the list of cached contents' do
      expect(conn).to receive(:get).with('https://generativelanguage.googleapis.com/v1beta/cachedContents') do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:params=)
        
        block.call(req)
        
        expect(req).to have_received(:params=).with(key: api_key)
        
        faraday_response
      end
      
      result = cached_content.list
      expect(result).to eq(response_instance)
    end
    
    it 'converts snake_case parameters to camelCase' do
      expect(conn).to receive(:get) do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:params=)
        
        block.call(req)
        
        expect(req).to have_received(:params=).with("pageSize" => 10, key: api_key)
        
        faraday_response
      end
      
      cached_content.list(parameters: { page_size: 10 })
    end
  end

  describe '#update' do
    let(:cache_name) { 'cachedContents/cache-123' }
    let(:new_ttl) { '7200s' }
    let(:update_response) { { 'name' => cache_name } }
    let(:faraday_response) { instance_double('Faraday::Response', body: update_response.to_json) }
    
    it 'updates the ttl of a cached content' do
      expect(conn).to receive(:patch).with("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:params=)
        allow(req).to receive(:body=)
        
        block.call(req)
        
        expect(req).to have_received(:params=).with(key: api_key)
        expect(req).to have_received(:body=) do |body_json|
          body = JSON.parse(body_json)
          expect(body['ttl']).to eq(new_ttl)
        end
        
        faraday_response
      end
      
      result = cached_content.update(name: cache_name, ttl: new_ttl)
      expect(result).to eq(response_instance)
    end
  end

  describe '#delete' do
    let(:cache_name) { 'cachedContents/cache-123' }
    let(:delete_response) { {} }
    let(:faraday_response) { instance_double('Faraday::Response', body: delete_response.to_json) }
    
    it 'deletes a cached content' do
      expect(conn).to receive(:delete).with("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |&block|
        req = double('request')
        allow(req).to receive(:headers=)
        allow(req).to receive(:params=)
        
        block.call(req)
        
        expect(req).to have_received(:params=).with(key: api_key)
        
        faraday_response
      end
      
      result = cached_content.delete(name: cache_name)
      expect(result).to eq(response_instance)
    end
  end
end