RSpec.describe Gemini::Client do
  let(:api_key) { ENV['GEMINI_API_KEY'] || 'test_api_key' }
  let(:client) { Gemini::Client.new(api_key) }
  let(:base_url) { "https://generativelanguage.googleapis.com/v1beta" }

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

  describe "#generate_content" do
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
      }.to_json
    end

    before do
      stub_request(:post, "#{base_url}/models/gemini-2.0-flash-lite:generateContent?key=#{api_key}")
        .with(
          body: {
            contents: [{ parts: [{ text: prompt }] }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "sends a request to generate content" do
      response = client.generate_content(prompt)
      expect(response["candidates"][0]["content"]["parts"][0]["text"]).to include("Ruby is a dynamic")
    end
  end

  describe "#chat" do
    let(:params) do
      {
        contents: [{ parts: [{ text: "What is Ruby?" }] }]
      }
    end
    let(:response_body) do
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                { "text" => "Ruby is a programming language..." }
              ],
              "role" => "model"
            }
          }
        ]
      }.to_json
    end

    before do
      # Match the actual model name being used
      stub_request(:post, "#{base_url}/models/gemini-2.0-flash-lite:generateContent?key=#{api_key}")
        .with(
          body: params.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end    
    it "sends a chat request" do
      response = client.chat(parameters: params)
      expect(response["candidates"][0]["content"]["parts"][0]["text"]).to include("Ruby is a programming language")
    end
  end

  describe "#embeddings" do
    let(:params) do
      {
        content: { parts: [{ text: "Ruby programming" }] }
        # Don't include model parameter (to match actual request)
      }
    end
    let(:response_body) do
      {
        "embedding" => {
          "values" => [0.1, 0.2, 0.3, 0.4, 0.5]
        }
      }.to_json
    end

    before do
      # Adjust stub to match actual request
      stub_request(:post, "#{base_url}/models/text-embedding-model:embedContent?key=#{api_key}")
        .with(
          body: params.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
    end

    it "sends an embeddings request" do
      response = client.embeddings(parameters: params)
      expect(response["embedding"]["values"]).to eq([0.1, 0.2, 0.3, 0.4, 0.5])
    end
  end
end