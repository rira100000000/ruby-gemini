require "spec_helper"

RSpec.describe Gemini::HTTPHeaders do
  let(:test_class) do
    Class.new do
      include Gemini::HTTPHeaders
    end
  end

  let(:instance) { test_class.new }

  describe "#add_headers" do
    it "adds headers" do # ヘッダーを追加できる
      instance.add_headers({ "X-Custom-Header" => "value" })
      expect(instance.send(:headers)).to include("X-Custom-Header" => "value")
    end

    it "converts symbol keys to strings" do # シンボルキーを文字列に変換する
      instance.add_headers({ :"X-Custom-Header" => "value" })
      expect(instance.send(:headers)).to include("X-Custom-Header" => "value")
    end

    it "overwrites existing headers" do # 既存のヘッダーを上書きする
      instance.add_headers({ "Content-Type" => "application/xml" })
      expect(instance.send(:headers)).to include("Content-Type" => "application/xml")
    end
  end

  describe "#headers" do
    it "includes default headers" do # デフォルトヘッダーを含む
      headers = instance.send(:headers)
      expect(headers).to include(
        "Content-Type" => "application/json",
        "User-Agent" => "ruby-gemini/#{Gemini::VERSION}"
      )
    end

    it "includes added headers" do # 追加されたヘッダーを含む
      instance.add_headers({ "X-Custom-Header" => "value" })
      headers = instance.send(:headers)
      expect(headers).to include("X-Custom-Header" => "value")
    end
  end
end