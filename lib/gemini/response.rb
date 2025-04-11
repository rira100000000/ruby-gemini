module Gemini
  class Response
    # Raw response data from API
    attr_reader :raw_data
    
    def initialize(response_data)
      @raw_data = response_data
    end
    
    # Get simple text response (combines multiple parts if present)
    def text
      return nil unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("text") }
        &.map { |part| part["text"] }
        &.join("\n") || ""
    end
    
    # Get formatted text (HTML/markdown, etc.)
    def formatted_text
      return nil unless valid?
      
      text # Currently returns plain text, but could add formatting in the future
    end
    
    # Get all content parts
    def parts
      return [] unless valid?
      
      first_candidate&.dig("content", "parts") || []
    end
    
    # Get all text parts as an array
    def text_parts
      return [] unless valid?
      
      parts.select { |part| part.key?("text") }.map { |part| part["text"] }
    end
    
    # Get image parts (if any)
    def image_parts
      return [] unless valid?
      
      parts.select { |part| part.key?("inline_data") && part["inline_data"]["mime_type"].start_with?("image/") }
    end
    
    # Get all content with string representation
    def full_content
      parts.map do |part|
        if part.key?("text")
          part["text"]
        elsif part.key?("inline_data") && part["inline_data"]["mime_type"].start_with?("image/")
          "[IMAGE: #{part["inline_data"]["mime_type"]}]"
        else
          "[UNKNOWN CONTENT]"
        end
      end.join("\n")
    end
    
    # Get the first candidate
    def first_candidate
      @raw_data&.dig("candidates", 0)
    end
    
    # Get all candidates (if multiple candidates are present)
    def candidates
      @raw_data&.dig("candidates") || []
    end
    
    # Check if response is valid
    def valid?
      !@raw_data.nil? && @raw_data.key?("candidates") && !@raw_data["candidates"].empty?
    end
    
    # Get error message if any
    def error
      return nil if valid?
      
      # Return nil for empty responses (to display "Empty response" in to_s method)
      return nil if @raw_data.nil? || @raw_data.empty?
      
      @raw_data&.dig("error", "message") || "Unknown error"
    end
    
    # Check if response was successful
    def success?
      valid? && !@raw_data.key?("error")
    end
    
    # Get finish reason (STOP, SAFETY, etc.)
    def finish_reason
      first_candidate&.dig("finishReason")
    end
    
    # Check if response was blocked for safety reasons
    def safety_blocked?
      finish_reason == "SAFETY"
    end
    
    # Get token usage information
    def usage
      @raw_data&.dig("usage") || {}
    end
    
    # Get number of prompt tokens used
    def prompt_tokens
      usage&.dig("promptTokens") || 0
    end
    
    # Get number of tokens used for completion
    def completion_tokens
      usage&.dig("candidateTokens") || 0
    end
    
    # Get total tokens used
    def total_tokens
      usage&.dig("totalTokens") || 0
    end
    
    # Process chunks for streaming responses
    def stream_chunks
      return [] unless @raw_data.is_a?(Array)
      
      @raw_data
    end
    
    # Get image URLs from multimodal responses (if any)
    def image_urls
      return [] unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("image_url") }
        &.map { |part| part.dig("image_url", "url") } || []
    end
    
    # Get function call information
    def function_calls
      return [] unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("functionCall") }
        &.map { |part| part["functionCall"] } || []
    end
    
    # Get response role (usually "model")
    def role
      first_candidate&.dig("content", "role")
    end
    
    # Get safety ratings
    def safety_ratings
      first_candidate&.dig("safetyRatings") || []
    end
    
    # Override to_s method to return text
    def to_s
      text || error || "Empty response"
    end
    
    # Inspection method for debugging
    def inspect
      "#<Gemini::Response text=#{text ? text[0..30] + (text.length > 30 ? '...' : '') : 'nil'} success=#{success?}>"
    end
  end
end