module Gemini
  class Files
    # Base URL for File API
    FILE_API_BASE_PATH = "files".freeze

    def initialize(client:)
      @client = client
    end

    # Method to upload a file
    def upload(file:, display_name: nil)
      # Check if file is valid
      raise ArgumentError, "No file specified" unless file

      # Get MIME type and size of the file
      mime_type = determine_mime_type(file)
      file.rewind
      file_size = file.size

      # Use filename as display_name if not specified
      display_name ||= File.basename(file.path) if file.respond_to?(:path)
      display_name ||= "uploaded_file"

      # Headers for initial upload request (metadata definition)
      headers = {
        "X-Goog-Upload-Protocol" => "resumable",
        "X-Goog-Upload-Command" => "start",
        "X-Goog-Upload-Header-Content-Length" => file_size.to_s,
        "X-Goog-Upload-Header-Content-Type" => mime_type,
        "Content-Type" => "application/json"
      }

      # Add debug output
      if ENV["DEBUG"]
        puts "Request URL: https://generativelanguage.googleapis.com/upload/v1beta/files"
        puts "Headers: #{headers.inspect}"
        puts "API Key: #{@client.api_key[0..5]}..." if @client.api_key
      end

      # Send initial request to get upload URL
      response = @client.conn.post("https://generativelanguage.googleapis.com/upload/v1beta/files") do |req|
        req.headers = headers
        req.params = { key: @client.api_key }
        req.body = { file: { display_name: display_name } }.to_json
      end

      # Get upload URL from response headers
      upload_url = response.headers["x-goog-upload-url"]
      raise "Failed to obtain upload URL" unless upload_url

      # Upload the file
      file.rewind
      file_data = file.read
      upload_response = @client.conn.post(upload_url) do |req|
        req.headers = {
          "Content-Length" => file_size.to_s,
          "X-Goog-Upload-Offset" => "0",
          "X-Goog-Upload-Command" => "upload, finalize"
        }
        req.body = file_data
      end

      # Parse response as JSON
      if upload_response.body.is_a?(String)
        JSON.parse(upload_response.body)
      elsif upload_response.body.is_a?(Hash)
        upload_response.body
      else
        raise "Invalid response format: #{upload_response.body.class}"
      end
    end

    # Method to get file metadata
    def get(name:)
      path = name.start_with?("files/") ? name : "files/#{name}"
      @client.get(path: path)
    end

    # Method to get list of uploaded files
    def list(page_size: nil, page_token: nil)
      parameters = {}
      parameters[:pageSize] = page_size if page_size
      parameters[:pageToken] = page_token if page_token

      @client.get(
        path: FILE_API_BASE_PATH,
        parameters: parameters
      )
    end

    # Method to delete a file
    def delete(name:)
      path = name.start_with?("files/") ? name : "files/#{name}"
      @client.delete(path: path)
    end

    private

    # Simple MIME type determination from file extension
    def determine_mime_type(file)
      return "application/octet-stream" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".png"
        "image/png"
      when ".gif"
        "image/gif"
      when ".webp"
        "image/webp"
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
      when ".mp4"
        "video/mp4"
      when ".avi"
        "video/avi"
      when ".mov"
        "video/quicktime"
      when ".mkv"
        "video/x-matroska"
      when ".pdf"
        "application/pdf"
      when ".txt"
        "text/plain"
      when ".doc", ".docx"
        "application/msword"
      when ".xlsx", ".xls"
        "application/vnd.ms-excel"
      when ".pptx", ".ppt"
        "application/vnd.ms-powerpoint"
      else
        # Default value
        "application/octet-stream"
      end
    end
  end
end