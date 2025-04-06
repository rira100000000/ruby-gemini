require "spec_helper"
require "vcr"

RSpec.describe Gemini::HTTP do
  let(:test_class) do
    Class.new do
      include Gemini::HTTP

      def initialize
        @api_key = "test-api-key"
        @uri_base = "https://api.gemini.com/v1beta"
        @request_timeout = 30
        @log_errors = true
      end
    end
  end

  let(:instance) { test_class.new }

  # VCR configuration
  before(:all) do
    VCR.configure do |config|
      config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
      config.hook_into :webmock
      # Filter sensitive data such as API keys
      # APIキーを隠すための設定
      config.filter_sensitive_data("<API_KEY>") { "test-api-key" }
      # Ignore headers that might change with each request
      # 同じリクエストでも毎回違うレスポンスを返す可能性があるヘッダーなどを無視
      config.ignore_request { |request| request.headers["X-Request-Id"] }
      # Allow VCR to record new HTTP interactions
      config.default_cassette_options = { 
        record: :new_episodes,
        match_requests_on: [:method, :uri]
      }
    end
  end

  describe "#get" do
    it "sends GET request with API key parameter" do # APIキーを含むパラメータでGETリクエストを送信する
      VCR.use_cassette("gemini_http_get") do
        stub_request(:get, "https://api.gemini.com/v1beta/test?key=test-api-key")
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.get(path: "test")
        expect(response).to eq({ "result" => "success" })
      end
    end

    it "can include additional parameters" do # 追加のパラメータを含めることができる
      VCR.use_cassette("gemini_http_get_with_params") do
        stub_request(:get, "https://api.gemini.com/v1beta/test?key=test-api-key&param=value")
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.get(path: "test", parameters: { param: "value" })
        expect(response).to eq({ "result" => "success" })
      end
    end
  end

  describe "#post" do
    it "sends POST request with API key parameter" do # APIキーを含むパラメータでPOSTリクエストを送信する
      VCR.use_cassette("gemini_http_post") do
        stub_request(:post, "https://api.gemini.com/v1beta/test?key=test-api-key")
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.post(path: "test")
        expect(response).to eq({ "result" => "success" })
      end
    end
  end

  describe "#json_post" do
    it "sends POST request with JSON body and API key parameter" do # JSONボディとAPIキーを含むパラメータでPOSTリクエストを送信する
      VCR.use_cassette("gemini_http_json_post") do
        stub_request(:post, "https://api.gemini.com/v1beta/test?key=test-api-key")
          .with(
            body: { data: "value" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.json_post(
          path: "test",
          parameters: { data: "value" }
        )
        expect(response).to eq({ "result" => "success" })
      end
    end

    it "can include query parameters" do # クエリパラメータを含めることができる
      VCR.use_cassette("gemini_http_json_post_with_query") do
        stub_request(:post, "https://api.gemini.com/v1beta/test?key=test-api-key&query=value")
          .with(
            body: { data: "value" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.json_post(
          path: "test",
          parameters: { data: "value" },
          query_parameters: { query: "value" }
        )
        expect(response).to eq({ "result" => "success" })
      end
    end
  end

  describe "#multipart_post" do
    # multipartの設定を確認
    before do
      # multipartアダプターを登録
      require 'faraday/multipart'
    end

    it "sends POST request with multipart form data" do # マルチパートフォームデータでPOSTリクエストを送信する
      VCR.use_cassette("gemini_http_multipart_post") do
        stub_request(:post, "https://api.gemini.com/v1beta/test?key=test-api-key")
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.multipart_post(path: "test")
        expect(response).to eq({ "result" => "success" })
      end
    end
  end

  describe "#delete" do
    it "sends DELETE request with API key parameter" do # APIキーを含むパラメータでDELETEリクエストを送信する
      VCR.use_cassette("gemini_http_delete") do
        stub_request(:delete, "https://api.gemini.com/v1beta/test?key=test-api-key")
          .to_return(status: 200, body: { result: "success" }.to_json, headers: { "Content-Type" => "application/json" })
        
        response = instance.delete(path: "test")
        expect(response).to eq({ "result" => "success" })
      end
    end
  end

  describe "#parse_json" do
    it "parses JSON string" do # JSON文字列をパースする
      json = { "result" => "success" }.to_json
      expect(instance.send(:parse_json, json)).to eq({ "result" => "success" })
    end

    it "converts multi-line JSON objects to array" do # 複数行のJSONオブジェクトを配列に変換する
      json = "{}\n{}"
      expect(instance.send(:parse_json, json)).to eq([{}, {}])
    end

    it "returns non-JSON string as is" do # JSONでない文字列はそのまま返す
      text = "plain text"
      expect(instance.send(:parse_json, text)).to eq(text)
    end

    it "returns nil as is" do # nilをそのまま返す
      expect(instance.send(:parse_json, nil)).to be_nil
    end
  end

  # Timeout tests
  describe "timeout handling" do
    let(:timeout_errors) { [Faraday::ConnectionFailed, Faraday::TimeoutError] }
    let(:timeout) { 0 }
    
    before do
      # タイムアウトするリクエストをスタブ
      stub_request(:get, "https://api.gemini.com/v1beta/test?key=test-api-key")
        .to_timeout
      
      stub_request(:post, "https://api.gemini.com/v1beta/test?key=test-api-key")
        .with(
          body: { data: "value" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
        .to_timeout
      
      instance.instance_variable_set(:@request_timeout, timeout)
    end

    describe "#get" do
      it "times out" do # タイムアウトする
        expect { instance.get(path: "test") }.to raise_error do |error|
          expect(timeout_errors).to include(error.class)
        end
      end
    end

    describe "#json_post" do
      it "times out" do # タイムアウトする
        expect { 
          instance.json_post(path: "test", parameters: { data: "value" }) 
        }.to raise_error do |error|
          expect(timeout_errors).to include(error.class)
        end
      end
    end
  end
end