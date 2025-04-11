require 'spec_helper'

RSpec.describe Gemini::Response do
  # Mock of a basic text response
  let(:basic_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => "This is a test response." }
            ],
            "role" => "model"
          },
          "finishReason" => "STOP",
          "index" => 0,
          "safetyRatings" => [
            { "category" => "HARM_CATEGORY_HARASSMENT", "probability" => "NEGLIGIBLE" }
          ]
        }
      ],
      "usage" => {
        "promptTokens" => 10,
        "candidateTokens" => 8,
        "totalTokens" => 18
      }
    }
  end

  # Mock of a response with multiple text parts
  let(:multi_part_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => "This is the first paragraph." },
              { "text" => "This is the second paragraph." },
              { "text" => "This is the final paragraph." }
            ],
            "role" => "model"
          },
          "finishReason" => "STOP",
          "index" => 0
        }
      ]
    }
  end

  # Mock of a multimodal response with both text and image
  let(:multimodal_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              { "text" => "Let me describe this image:" },
              { 
                "inline_data" => {
                  "mime_type" => "image/jpeg",
                  "data" => "base64encodeddata"
                }
              },
              { "text" => "That's my analysis of the image." }
            ],
            "role" => "model"
          },
          "finishReason" => "STOP",
          "index" => 0
        }
      ]
    }
  end

  # Mock of a function call response
  let(:function_call_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => [
              {
                "functionCall" => {
                  "name" => "get_weather",
                  "args" => {
                    "location" => "Tokyo",
                    "unit" => "celsius"
                  }
                }
              }
            ],
            "role" => "model"
          },
          "finishReason" => "STOP",
          "index" => 0
        }
      ]
    }
  end

  # Mock of an error response
  let(:error_response_data) do
    {
      "error" => {
        "code" => 400,
        "message" => "Invalid request: Model not found",
        "status" => "INVALID_ARGUMENT"
      }
    }
  end

  # Mock of a streaming response (array format)
  let(:streaming_response_data) do
    [
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [{ "text" => "Hel" }],
              "role" => "model"
            },
            "index" => 0
          }
        ]
      },
      {
        "candidates" => [
          {
            "content" => {
              "parts" => [{ "text" => "lo" }]
            },
            "index" => 0
          }
        ]
      }
    ]
  end

  # Mock of an empty response
  let(:empty_response_data) do
    {}
  end

  # Mock of a safety blocked response
  let(:safety_blocked_response_data) do
    {
      "candidates" => [
        {
          "content" => {
            "parts" => []
          },
          "finishReason" => "SAFETY",
          "index" => 0,
          "safetyRatings" => [
            { "category" => "HARM_CATEGORY_DANGEROUS", "probability" => "HIGH" }
          ]
        }
      ]
    }
  end

  describe '#initialize' do
    it 'stores the raw response data' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.raw_data).to eq(basic_response_data)
    end
  end

  describe '#text' do
    it 'returns the text from a basic response' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.text).to eq("This is a test response.")
    end

    it 'concatenates multiple text parts with newlines' do
      response = Gemini::Response.new(multi_part_response_data)
      expected_text = "This is the first paragraph.\nThis is the second paragraph.\nThis is the final paragraph."
      expect(response.text).to eq(expected_text)
    end

    it 'returns only text parts from a multimodal response' do
      response = Gemini::Response.new(multimodal_response_data)
      expected_text = "Let me describe this image:\nThat's my analysis of the image."
      expect(response.text).to eq(expected_text)
    end

    it 'returns nil for error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.text).to be_nil
    end

    it 'returns an empty string when no text parts exist' do
      response = Gemini::Response.new({ "candidates" => [{ "content" => { "parts" => [] } }] })
      expect(response.text).to eq("")
    end
  end

  describe '#parts' do
    it 'returns all parts from the response' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.parts.size).to eq(3)
      expect(response.parts.first).to eq({ "text" => "This is the first paragraph." })
    end

    it 'returns empty array for invalid responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.parts).to eq([])
    end
  end

  describe '#text_parts' do
    it 'returns only text parts as strings' do
      response = Gemini::Response.new(multimodal_response_data)
      expect(response.text_parts).to eq(["Let me describe this image:", "That's my analysis of the image."])
    end

    it 'returns empty array for invalid responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.text_parts).to eq([])
    end
  end

  describe '#image_parts' do
    it 'returns only image parts' do
      response = Gemini::Response.new(multimodal_response_data)
      image_parts = response.image_parts
      expect(image_parts.size).to eq(1)
      expect(image_parts.first["inline_data"]["mime_type"]).to eq("image/jpeg")
    end

    it 'returns empty array when no image parts exist' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.image_parts).to eq([])
    end
  end

  describe '#full_content' do
    it 'formats all content types appropriately' do
      response = Gemini::Response.new(multimodal_response_data)
      expected = "Let me describe this image:\n[IMAGE: image/jpeg]\nThat's my analysis of the image."
      expect(response.full_content).to eq(expected)
    end
  end

  describe '#valid?' do
    it 'returns true for valid responses' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.valid?).to be true
    end

    it 'returns false for error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.valid?).to be false
    end

    it 'returns false for empty responses' do
      response = Gemini::Response.new(empty_response_data)
      expect(response.valid?).to be false
    end

    it 'returns false for nil responses' do
      response = Gemini::Response.new(nil)
      expect(response.valid?).to be false
    end
  end

  describe '#error' do
    it 'returns the error message for error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.error).to eq("Invalid request: Model not found")
    end

    it 'returns nil for successful responses' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.error).to be_nil
    end
  end

  describe '#success?' do
    it 'returns true for successful responses' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.success?).to be true
    end

    it 'returns false for error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.success?).to be false
    end
  end

  describe '#finish_reason' do
    it 'returns the finish reason from response' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.finish_reason).to eq("STOP")
    end

    it 'returns nil when finish reason is not present' do
      response = Gemini::Response.new(empty_response_data)
      expect(response.finish_reason).to be_nil
    end
  end

  describe '#safety_blocked?' do
    it 'returns true when content was blocked for safety reasons' do
      response = Gemini::Response.new(safety_blocked_response_data)
      expect(response.safety_blocked?).to be true
    end

    it 'returns false for normal completed responses' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.safety_blocked?).to be false
    end
  end

  describe '#usage' do
    it 'returns the token usage data' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.usage).to eq({
        "promptTokens" => 10,
        "candidateTokens" => 8,
        "totalTokens" => 18
      })
    end

    it 'returns empty hash when usage data is not present' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.usage).to eq({})
    end
  end

  describe '#prompt_tokens' do
    it 'returns the number of prompt tokens used' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.prompt_tokens).to eq(10)
    end

    it 'returns 0 when usage data is not present' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.prompt_tokens).to eq(0)
    end
  end

  describe '#completion_tokens' do
    it 'returns the number of candidate tokens used' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.completion_tokens).to eq(8)
    end

    it 'returns 0 when usage data is not present' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.completion_tokens).to eq(0)
    end
  end

  describe '#total_tokens' do
    it 'returns the total number of tokens used' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.total_tokens).to eq(18)
    end

    it 'returns 0 when usage data is not present' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.total_tokens).to eq(0)
    end
  end

  describe '#stream_chunks' do
    it 'returns the array of chunks for streaming responses' do
      response = Gemini::Response.new(streaming_response_data)
      expect(response.stream_chunks).to eq(streaming_response_data)
    end

    it 'returns empty array for non-streaming responses' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.stream_chunks).to eq([])
    end
  end

  describe '#function_calls' do
    it 'returns function call data when present' do
      response = Gemini::Response.new(function_call_response_data)
      function_calls = response.function_calls
      expect(function_calls.size).to eq(1)
      expect(function_calls.first["name"]).to eq("get_weather")
      expect(function_calls.first["args"]["location"]).to eq("Tokyo")
    end

    it 'returns empty array when no function calls exist' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.function_calls).to eq([])
    end
  end

  describe '#role' do
    it 'returns the role of the response' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.role).to eq("model")
    end

    it 'returns nil when role is not present' do
      response = Gemini::Response.new(empty_response_data)
      expect(response.role).to be_nil
    end
  end

  describe '#safety_ratings' do
    it 'returns the safety ratings when present' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.safety_ratings).to eq([
        { "category" => "HARM_CATEGORY_HARASSMENT", "probability" => "NEGLIGIBLE" }
      ])
    end

    it 'returns empty array when safety ratings are not present' do
      response = Gemini::Response.new(multi_part_response_data)
      expect(response.safety_ratings).to eq([])
    end
  end

  describe '#to_s' do
    it 'returns the text response as string' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.to_s).to eq("This is a test response.")
    end

    it 'returns error message as string for error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.to_s).to eq("Invalid request: Model not found")
    end

    it 'returns "Empty response" for empty responses' do
      response = Gemini::Response.new(empty_response_data)
      expect(response.to_s).to eq("Empty response")
    end
  end

  describe '#inspect' do
    it 'includes truncated text and success status in inspect string' do
      response = Gemini::Response.new(basic_response_data)
      expect(response.inspect).to eq('#<Gemini::Response text=This is a test response. success=true>')
    end

    it 'truncates long text responses with ellipsis' do
      long_text_response = {
        "candidates" => [
          {
            "content" => {
              "parts" => [{ "text" => "This is a very long response that should be truncated in the inspect output" }]
            }
          }
        ]
      }
      response = Gemini::Response.new(long_text_response)
      expect(response.inspect).to eq('#<Gemini::Response text=This is a very long response th... success=true>')
    end

    it 'shows nil for text in error responses' do
      response = Gemini::Response.new(error_response_data)
      expect(response.inspect).to eq('#<Gemini::Response text=nil success=false>')
    end
  end
end