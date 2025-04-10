module Gemini
  class Audio
    def initialize(client:)
      @client = client
    end

    # Transcribe an audio file
    def transcribe(parameters: {})
      file = parameters.delete(:file)
      file_uri = parameters.delete(:file_uri)
      model = parameters.delete(:model) || "gemini-1.5-flash"
      language = parameters.delete(:language)
      content_text = parameters.delete(:content_text) || "Transcribe this audio clip"
      
      if !file && !file_uri
        raise ArgumentError, "No audio file specified"
      end

      if file_uri
        response = transcribe_with_file_uri(file_uri, model, language, content_text, parameters)
        return Gemini::Response.new(response)
      end
      
      # Get MIME type (simple detection)
      mime_type = determine_mime_type(file)

      # Base64 encode the file
      file.rewind
      require 'base64'
      file_data = Base64.strict_encode64(file.read)
      
      # Language setting for transcription request
      if language
        content_text += " in #{language}"
      end
      
      # Build request parameters
      request_params = {
        contents: [{
          parts: [
            { text: content_text },
            { 
              inline_data: { 
                mime_type: mime_type,
                data: file_data
              } 
            }
          ]
        }]
      }
      
      # Merge additional parameters (add to top level except contents)
      parameters.each do |key, value|
        request_params[key] = value unless key == :contents
      end
      
      # Send generateContent request
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      # Format response
      Gemini::Response.new(format_response(response))
    end
    
    private

    # Transcribe using pre-uploaded file URI
    def transcribe_with_file_uri(file_uri, model, language, content_text, parameters)
      # Language setting for transcription request
      if language
        content_text += " in #{language}"
      end
      
      # Build request parameters
      request_params = {
        contents: [{
          parts: [
            { text: content_text },
            { 
              file_data: { 
                mime_type: "audio/mp3", # Cannot determine MIME type from URI, so using default value
                file_uri: file_uri
              } 
            }
          ]
        }]
      }
      
      # Merge additional parameters (add to top level except contents)
      parameters.each do |key, value|
        request_params[key] = value unless key == :contents
      end
      
      # Send generateContent request
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      # Format response
      format_response(response)
    end
    
    # Simple MIME type determination from file extension
    def determine_mime_type(file)
      return "application/octet-stream" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
      when ".wav"
        "audio/wav"
      when ".mp3"
        "audio/mp3"
      when ".aiff"
        "audio/aiff"
      when ".aac"
        "audio/aac"
      when ".ogg"
        "audio/ogg"
      when ".flac"
        "audio/flac"
      else
        # Default value (assume mp3)
        "audio/mp3"
      end
    end
    
    # Format Gemini API response to OpenAI format
    def format_response(response)
      # Extract text portion from response
      if response["candidates"] && !response["candidates"].empty?
        candidate = response["candidates"][0]
        if candidate["content"] && candidate["content"]["parts"] && !candidate["content"]["parts"].empty?
          text = candidate["content"]["parts"][0]["text"]
          
          # OpenAI-like response
          return {
            "text" => text,
            "raw_response" => response # Include original response
          }
        end
      end
      
      # Return empty response if text not found
      { "text" => "", "raw_response" => response }
    end
  end
end