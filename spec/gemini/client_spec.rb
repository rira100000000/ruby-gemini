require 'spec_helper'

RSpec.describe Gemini::Client do
  let(:api_key) { ENV['GEMINI_API_KEY'] || 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }
  let(:response_instance) { instance_double(Gemini::Response) }

  describe "#initialize" do
    it "initializes with an API key" do
      expect(client.api_key).to eq(api_key)
    end

    it "raises an error without API key" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect { Gemini::Client.new }.to raise_error(Gemini::ConfigurationError)
    end

    it "uses the API key from the environment if not provided" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("env_api_key")
      client = Gemini::Client.new
      expect(client.api_key).to eq("env_api_key")
    end
  end

  # test for image function
  describe "#generate_content with image" do
    let(:sample_text_response) { "This is a guinea pig in the image." }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => sample_text_response }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return(sample_text_response)
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    context "with image_url" do
      let(:image_url) { "https://example.com/guinea_pig.jpg" }
      let(:prompt) { [
        { type: "text", text: "What is in this image?" },
        { type: "image_url", image_url: { url: image_url } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_url).with(image_url).and_return("base64_encoded_image_data")
        allow(client).to receive(:determine_mime_type).with(image_url).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.0-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "What is in this image?" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with image url data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.0-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with image_file" do
      let(:file_path) { "/path/to/guinea_pig.jpg" }
      let(:prompt) { [
        { type: "text", text: "Describe this image" },
        { type: "image_file", image_file: { file_path: file_path } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_file).with(file_path).and_return("base64_encoded_image_data")
        allow(client).to receive(:determine_mime_type).with(file_path).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.0-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "Describe this image" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with image file data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.0-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with image_base64" do
      let(:base64_data) { "base64_encoded_image_data" }
      let(:prompt) { [
        { type: "text", text: "What can you see in this image?" },
        { type: "image_base64", image_base64: { mime_type: "image/jpeg", data: base64_data } }
      ] }
      
      before do
        stub_request(:post, "#{base_url}/models/gemini-2.0-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "What can you see in this image?" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: base64_data
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with direct base64 image data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.0-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end

    context "with multiple images" do
      let(:image_url1) { "https://example.com/guinea_pig1.jpg" }
      let(:image_url2) { "https://example.com/guinea_pig2.jpg" }
      let(:prompt) { [
        { type: "text", text: "Compare these two images" },
        { type: "image_url", image_url: { url: image_url1 } },
        { type: "image_url", image_url: { url: image_url2 } }
      ] }
      
      before do
        # mock Base64 encoded data
        allow(client).to receive(:encode_image_from_url).with(image_url1).and_return("base64_encoded_image_data1")
        allow(client).to receive(:encode_image_from_url).with(image_url2).and_return("base64_encoded_image_data2")
        allow(client).to receive(:determine_mime_type).with(image_url1).and_return("image/jpeg")
        allow(client).to receive(:determine_mime_type).with(image_url2).and_return("image/jpeg")

        stub_request(:post, "#{base_url}/models/gemini-2.0-flash:generateContent?key=#{api_key}")
          .with(
            body: hash_including(
              contents: [
                { 
                  parts: [
                    { text: "Compare these two images" },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data1"
                      }
                    },
                    { 
                      inline_data: {
                        mime_type: "image/jpeg",
                        data: "base64_encoded_image_data2"
                      }
                    }
                  ]
                }
              ]
            ),
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sends a request with multiple image data and returns Response object" do
        response = client.generate_content(prompt, model: "gemini-2.0-flash")
        expect(response).to be(response_instance)
        expect(response.text).to eq(sample_text_response)
      end
    end
  end
  
  describe "#chat" do
    let(:model) { "gemini-2.0-flash-lite" }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Hello, how can I help you today?" }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Hello, how can I help you today?")
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    context "with non-streaming response" do
      it "sends a generateContent request and returns Response object" do
        stub_request(:post, "#{base_url}/models/#{model}:generateContent?key=#{api_key}")
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
          
        response = client.chat(parameters: { contents: [{ parts: [{ text: "Hi" }] }] })
        expect(response).to be(response_instance)
        expect(response.text).to eq("Hello, how can I help you today?")
      end
    end

    context "with streaming response" do
      it "sends a streamGenerateContent request and returns Response object" do
        stub_request(:post, "#{base_url}/models/#{model}:streamGenerateContent?alt=sse&key=#{api_key}")
          .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
          
        callback = proc { |chunk| }
        response = client.chat(parameters: { contents: [{ parts: [{ text: "Hi" }] }] }, &callback)
        expect(response).to be(response_instance)
      end
    end
  end

  describe "#embeddings" do
    let(:model) { "text-embedding-model" }
    let(:response_body) do
      {
        "embedding" => {
          "values" => [0.1, 0.2, 0.3]
        }
      }
    end

    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:raw_data).and_return(response_body)
    end

    it "sends an embedContent request and returns Response object" do
      stub_request(:post, "#{base_url}/models/#{model}:embedContent?key=#{api_key}")
        .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
        
      response = client.embeddings(parameters: { content: { parts: [{ text: "Embed this text" }] } })
      expect(response).to be(response_instance)
    end
  end

  describe "#completions" do
    it "delegates to chat method and returns Response object" do
      params = { contents: [{ parts: [{ text: "Complete this" }] }] }
      expect(client).to receive(:chat).with(parameters: params).and_return(response_instance)
      
      response = client.completions(parameters: params)
      expect(response).to be(response_instance)
    end
  end

  describe "#generate_content_stream" do
    let(:model) { "gemini-2.0-flash-lite" }
    
    before do
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
    end

    it "requires a block" do
      expect { client.generate_content_stream("Hello") }.to raise_error(ArgumentError, "Block is required for streaming")
    end

    it "sends a streaming request and returns Response object" do
      prompt = "Tell me a story"
      
      expect(client).to receive(:chat) do |parameters:, &block|
        expect(parameters[:contents][0][:parts][0][:text]).to eq(prompt)
        expect(parameters[:model]).to eq(model)
        expect(block).to be_a(Proc)
        response_instance
      end
      
      callback = proc { |chunk| }
      response = client.generate_content_stream(prompt, &callback)
      expect(response).to be(response_instance)
    end
  end

  # helper method test
  describe "#determine_mime_type" do
    it "correctly identifies JPEG images" do
      expect(client.send(:determine_mime_type, "image.jpg")).to eq("image/jpeg")
      expect(client.send(:determine_mime_type, "photo.jpeg")).to eq("image/jpeg")
    end

    it "correctly identifies PNG images" do
      expect(client.send(:determine_mime_type, "icon.png")).to eq("image/png")
    end

    it "correctly identifies other supported formats" do
      expect(client.send(:determine_mime_type, "animation.gif")).to eq("image/gif")
      expect(client.send(:determine_mime_type, "photo.webp")).to eq("image/webp")
      expect(client.send(:determine_mime_type, "photo.heic")).to eq("image/heic")
      expect(client.send(:determine_mime_type, "photo.heif")).to eq("image/heif")
    end

    it "defaults to JPEG for unknown formats" do
      expect(client.send(:determine_mime_type, "unknown.xyz")).to eq("image/jpeg")
    end
  end

  describe "#encode_image_from_file" do
    let(:file_path) { "spec/fixtures/guinea_pig.jpg" }
    let(:binary_data) { "mock_binary_data" }
    let(:encoded_data) { "bW9ja19iaW5hcnlfZGF0YQ==" } # Base64 encoded "mock_binary_data"

    before do
      allow(File).to receive(:binread).with(file_path).and_return(binary_data)
    end

    it "reads file in binary mode and encodes to base64" do
      expect(client.send(:encode_image_from_file, file_path)).to eq(encoded_data)
      expect(File).to have_received(:binread).with(file_path)
    end

    it "raises error for non-existent files" do
      allow(File).to receive(:binread).with("non_existent.jpg").and_raise(Errno::ENOENT.new("No such file"))
      expect { client.send(:encode_image_from_file, "non_existent.jpg") }
        .to raise_error(Gemini::Error, /Failed to load image from file/)
    end
  end

  describe "#encode_image_from_url" do
    let(:image_url) { "https://example.com/guinea_pig.jpg" }
    let(:binary_data) { "mock_binary_data" }
    let(:encoded_data) { "bW9ja19iaW5hcnlfZGF0YQ==" } # Base64 encoded "mock_binary_data"
    let(:mock_io) { StringIO.new(binary_data) }

    before do
      require 'open-uri'
      allow(URI).to receive(:open).with(image_url, 'rb').and_return(mock_io)
    end

    it "opens URL in binary mode and encodes to base64" do
      expect(client.send(:encode_image_from_url, image_url)).to eq(encoded_data)
      expect(URI).to have_received(:open).with(image_url, 'rb')
    end

    it "raises error for invalid URLs" do
      allow(URI).to receive(:open).with("invalid_url", 'rb').and_raise(OpenURI::HTTPError.new("404 Not Found", StringIO.new))
      expect { client.send(:encode_image_from_url, "invalid_url") }
        .to raise_error(Gemini::Error, /Failed to load image from URL/)
    end
  end

  describe "#generate_content with text only" do
    let(:prompt) { "Tell me a story about Ruby" }
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Ruby is a dynamic, interpreted language..." }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ]
      }
    end

    before do
      stub_request(:post, "#{base_url}/models/gemini-2.0-flash-lite:generateContent?key=#{api_key}")
        .with(
          body: {
            contents: [{ parts: [{ text: prompt }] }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body.to_json, headers: { "Content-Type" => "application/json" })
      
      allow(Gemini::Response).to receive(:new).and_return(response_instance)
      allow(response_instance).to receive(:text).and_return("Ruby is a dynamic, interpreted language...")
    end

    it "sends a text-only request and returns Response object" do
      response = client.generate_content(prompt)
      expect(response).to be(response_instance)
      expect(response.text).to include("Ruby is a dynamic")
    end
  end
end