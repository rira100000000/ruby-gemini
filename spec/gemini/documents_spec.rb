require 'spec_helper'

RSpec.describe Gemini::Documents do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double('Gemini::Client') }
  let(:files) { instance_double('Gemini::Files') }
  let(:cached_content) { instance_double('Gemini::CachedContent') }
  let(:documents) { Gemini::Documents.new(client: client) }
  let(:response_instance) { instance_double('Gemini::Response') }
  
  before do
    allow(client).to receive(:files).and_return(files)
    allow(client).to receive(:cached_content).and_return(cached_content)
    allow(Gemini::Response).to receive(:new).and_return(response_instance)
  end

  describe '#process' do
    let(:file_path) { '/path/to/document.pdf' }
    let(:file) { instance_double('File') }
    let(:file_uri) { 'files/document-123' }
    let(:file_name) { 'files/document-123' }
    let(:mime_type) { 'application/pdf' }
    let(:prompt) { 'Summarize this document' }
    let(:model) { 'gemini-1.5-flash' }
    let(:upload_response) { { 'file' => { 'uri' => file_uri, 'name' => file_name } } }
    let(:generate_content_response) { { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Document summary' }] } }] } }
    
    context 'with file parameter' do
      before do
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(client).to receive(:generate_content).and_return(response_instance)
      end
      
      it 'uploads the file and generates content' do
        result = documents.process(file: file, prompt: prompt, model: model, mime_type: mime_type)
        
        expect(files).to have_received(:upload).with(file: file)
        expect(client).to have_received(:generate_content).with(
          [
            { text: prompt },
            { file_data: { mime_type: mime_type, file_uri: file_uri } }
          ],
          model: model
        )
        
        expect(result).to include(
          response: response_instance,
          file_uri: file_uri,
          file_name: file_name
        )
      end
    end
    
    context 'with file_path parameter' do
      before do
        allow(File).to receive(:open).with(file_path, 'rb').and_return(file)
        allow(file).to receive(:close)
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(client).to receive(:generate_content).and_return(response_instance)
      end
      
      it 'opens the file, uploads it, and generates content' do
        result = documents.process(file_path: file_path, prompt: prompt, model: model, mime_type: mime_type)
        
        expect(File).to have_received(:open).with(file_path, 'rb')
        expect(files).to have_received(:upload).with(file: file)
        expect(file).to have_received(:close)
        expect(client).to have_received(:generate_content).with(
          [
            { text: prompt },
            { file_data: { mime_type: mime_type, file_uri: file_uri } }
          ],
          model: model
        )
        
        expect(result).to include(
          response: response_instance,
          file_uri: file_uri,
          file_name: file_name
        )
      end
    end
    
    context 'when determining MIME type' do
      let(:temp_file) { instance_double('File') }
      
      before do
        allow(File).to receive(:open).with(file_path, 'rb').and_return(temp_file)
        allow(temp_file).to receive(:close)
        allow(temp_file).to receive(:path).and_return(file_path)
        allow(temp_file).to receive(:rewind)
        allow(temp_file).to receive(:read).with(4).and_return("%PDF")
        allow(files).to receive(:upload).with(file: temp_file).and_return(upload_response)
        allow(client).to receive(:generate_content).and_return(response_instance)
      end
      
      it 'determines MIME type from file extension' do
        allow(File).to receive(:extname).with(file_path).and_return('.pdf')
        
        documents.process(file_path: file_path, prompt: prompt, model: model)
        
        expect(client).to have_received(:generate_content).with(
          array_including(hash_including(file_data: { mime_type: 'application/pdf', file_uri: file_uri })),
          hash_including(model: model)
        )
      end
      
      it 'determines MIME type for different document types' do
        {
          '.pdf' => 'application/pdf',
          '.js' => 'application/x-javascript',
          '.py' => 'application/x-python',
          '.txt' => 'text/plain',
          '.html' => 'text/html',
          '.css' => 'text/css',
          '.md' => 'text/md',
          '.csv' => 'text/csv',
          '.xml' => 'text/xml',
          '.rtf' => 'text/rtf',
          '.unknown' => 'application/octet-stream'
        }.each do |ext, mime|
          allow(File).to receive(:extname).with(file_path).and_return(ext)
          
          if ext == '.pdf'
            allow(temp_file).to receive(:read).with(4).and_return("%PDF")
          else
            allow(temp_file).to receive(:read).with(4).and_return("XXXX")
          end
          
          documents.process(file_path: file_path, prompt: prompt, model: model)
          
          expect(client).to have_received(:generate_content).with(
            array_including(hash_including(file_data: { mime_type: mime, file_uri: file_uri })),
            hash_including(model: model)
          )
        end
      end
      
      it 'detects PDF MIME type from content when extension is missing' do
        allow(File).to receive(:extname).with(file_path).and_return('.unknown')
        allow(temp_file).to receive(:read).with(4).and_return("%PDF")
        
        documents.process(file_path: file_path, prompt: prompt, model: model)
        
        expect(client).to have_received(:generate_content).with(
          array_including(hash_including(file_data: { mime_type: 'application/pdf', file_uri: file_uri })),
          hash_including(model: model)
        )
      end
    end
    
    context 'without file or file_path' do
      it 'raises an argument error' do
        expect {
          documents.process(prompt: prompt, model: model)
        }.to raise_error(ArgumentError, 'file or file_path parameter is required')
      end
    end
    
    context 'with additional parameters' do
      before do
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(client).to receive(:generate_content).and_return(response_instance)
      end
      
      it 'passes additional parameters to generate_content' do
        documents.process(
          file: file, 
          prompt: prompt, 
          model: model, 
          mime_type: mime_type, 
          temperature: 0.7, 
          top_k: 40
        )
        
        expect(client).to have_received(:generate_content).with(
          [
            { text: prompt },
            { file_data: { mime_type: mime_type, file_uri: file_uri } }
          ],
          model: model,
          temperature: 0.7,
          top_k: 40
        )
      end
    end
  end

  describe '#cache' do
    let(:file_path) { '/path/to/document.pdf' }
    let(:file) { instance_double('File') }
    let(:file_uri) { 'files/document-123' }
    let(:file_name) { 'files/document-123' }
    let(:mime_type) { 'application/pdf' }
    let(:system_instruction) { 'You are an expert at analyzing documents.' }
    let(:ttl) { '86400s' }
    let(:model) { 'gemini-1.5-flash' }
    let(:upload_response) { { 'file' => { 'uri' => file_uri, 'name' => file_name } } }
    let(:cache_response) { { 'name' => 'cachedContents/cache-123' } }
    
    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
    end
    
    context 'with file parameter' do
      before do
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(cached_content).to receive(:create).and_return(response_instance)
      end
      
      it 'uploads the file and creates cache' do
        result = documents.cache(
          file: file, 
          system_instruction: system_instruction, 
          ttl: ttl, 
          model: model,
          mime_type: mime_type
        )
        
        expect(files).to have_received(:upload).with(file: file)
        # モデル名がmodels/プレフィックスを持つようになっていることを反映
        expect(cached_content).to have_received(:create).with(
          file_uri: file_uri,
          mime_type: mime_type,
          system_instruction: system_instruction,
          model: "models/#{model}",
          ttl: ttl
        )
        
        expect(result).to include(
          cache: response_instance,
          file_uri: file_uri,
          file_name: file_name
        )
      end
    end
    
    context 'with file_path parameter' do
      before do
        allow(File).to receive(:open).with(file_path, 'rb').and_return(file)
        allow(file).to receive(:close)
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(cached_content).to receive(:create).and_return(response_instance)
      end
      
      it 'opens the file, uploads it, and creates cache' do
        result = documents.cache(
          file_path: file_path, 
          system_instruction: system_instruction, 
          ttl: ttl, 
          model: model,
          mime_type: mime_type
        )
        
        expect(File).to have_received(:open).with(file_path, 'rb')
        expect(files).to have_received(:upload).with(file: file)
        expect(file).to have_received(:close)
        # モデル名がmodels/プレフィックスを持つようになっていることを反映
        expect(cached_content).to have_received(:create).with(
          file_uri: file_uri,
          mime_type: mime_type,
          system_instruction: system_instruction,
          model: "models/#{model}",
          ttl: ttl
        )
        
        expect(result).to include(
          cache: response_instance,
          file_uri: file_uri,
          file_name: file_name
        )
      end
    end
    
    context 'without file or file_path' do
      it 'raises an argument error' do
        expect {
          documents.cache(system_instruction: system_instruction, model: model)
        }.to raise_error(ArgumentError, 'file or file_path parameter is required')
      end
    end
    
    context 'with model name handling' do
      before do
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(cached_content).to receive(:create).and_return(response_instance)
      end
      
      it 'passes the model name correctly to cached_content.create' do
        documents.cache(
          file: file, 
          model: 'gemini-1.5-flash',
          mime_type: mime_type
        )
        
        # モデル名にmodels/プレフィックスが追加されることを確認
        expect(cached_content).to have_received(:create).with(
          hash_including(model: 'models/gemini-1.5-flash')
        )
      end
      
      it 'handles model names with models/ prefix' do
        documents.cache(
          file: file, 
          model: 'models/gemini-1.5-flash',
          mime_type: mime_type
        )
        
        expect(cached_content).to have_received(:create).with(
          hash_including(model: 'models/gemini-1.5-flash')
        )
      end
    end
    
    context 'with additional parameters' do
      before do
        allow(files).to receive(:upload).with(file: file).and_return(upload_response)
        allow(cached_content).to receive(:create).and_return(response_instance)
      end
      
      it 'passes additional parameters to cached_content.create' do
        documents.cache(
          file: file,
          system_instruction: system_instruction,
          ttl: ttl,
          model: model,
          mime_type: mime_type,
          display_name: 'My Cached Document'
        )
        
        # モデル名にmodels/プレフィックスが追加されることを確認
        expect(cached_content).to have_received(:create).with(
          file_uri: file_uri,
          mime_type: mime_type,
          system_instruction: system_instruction,
          model: "models/#{model}",
          ttl: ttl,
          display_name: 'My Cached Document'
        )
      end
    end
  end
end