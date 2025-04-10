require 'bundler/setup'
require 'gemini'
require 'logger'

# Enable debug mode
ENV["DEBUG"] = "true"

# Logger configuration
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Audio file transcription demo using File API (Debug Mode)"
  puts "==============================================="
  
  # Specify audio file path
  audio_file_path = ARGV[0] || raise("Usage: ruby file_api_debug.rb <audio file path>")
  
  # Check if file exists
  unless File.exist?(audio_file_path)
    raise "File not found: #{audio_file_path}"
  end
  
  # Display file information
  file_size = File.size(audio_file_path) / 1024.0 # KB unit
  file_extension = File.extname(audio_file_path)
  puts "File: #{File.basename(audio_file_path)}"
  puts "Size: #{file_size.round(2)} KB"
  puts "Type: #{file_extension}"
  puts "==============================================="
  
  # Process start time
  start_time = Time.now
  
  # Upload file
  logger.info "Uploading audio file..."
  puts "Uploading..."
  
  # Check client information
  puts "Client information:"
  puts "URI Base: #{client.uri_base}"
  
  file = File.open(audio_file_path, "rb")
  begin
    # Upload process
    puts "Starting file upload process..."
    upload_result = client.files.upload(file: file)
    
    # Process if successful
    file_uri = upload_result["file"]["uri"]
    file_name = upload_result["file"]["name"]
    
    puts "File uploaded:"
    puts "File URI: #{file_uri}"
    puts "File Name: #{file_name}"
    puts "Complete response: #{upload_result.inspect}"
    
    # Execute transcription
    logger.info "Executing transcription of uploaded file..."
    puts "Transcribing..."
    
    # Add retry logic (for 503 error)
    max_retries = 3
    retry_count = 0
    retry_delay = 2 # Initial delay (seconds)
    
    begin
      response = client.audio.transcribe(
        parameters: {
          file_uri: file_uri,
          language: "ja", # Specify language (change as needed)
          content_text: "Please transcribe this audio."
        }
      )
    rescue Faraday::ServerError => e
      retry_count += 1
      if retry_count <= max_retries
        puts "Server error occurred. Retrying in #{retry_delay} seconds... (#{retry_count}/#{max_retries})"
        sleep retry_delay
        # Exponential backoff (double delay)
        retry_delay *= 2
        retry
      else
        raise e
      end
    end
    
    # Process end time and elapsed time calculation
    end_time = Time.now
    elapsed_time = end_time - start_time
    
    # Display results
    puts "\n=== Transcription Result ==="
    puts response["text"]
    puts "======================="
    puts "Processing time: #{elapsed_time.round(2)} seconds"
    
    # Display uploaded file information
    begin
      file_info = client.files.get(name: file_name)
      puts "\n=== File Information ==="
      puts "Name: #{file_info['name']}"
      puts "Display Name: #{file_info['displayName']}" if file_info['displayName']
      puts "MIME Type: #{file_info['mimeType']}" if file_info['mimeType']
      puts "Size: #{file_info['sizeBytes'].to_i / 1024.0} KB" if file_info['sizeBytes']
      puts "Creation Date: #{Time.at(file_info['createTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['createTime']
      puts "Expiration: #{Time.at(file_info['expirationTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['expirationTime']
      puts "URI: #{file_info['uri']}" if file_info['uri']
      puts "Status: #{file_info['state']}" if file_info['state']
      puts "======================="
    rescue => e
      puts "Failed to get file information: #{e.message}"
    end
    
      puts "File will be automatically deleted after 48 hours"
  rescue => e
    puts "Error occurred during file upload: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n") if ENV["DEBUG"]
  ensure
    file.close
  end
  
rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
  
  puts "\nDetailed error information:"
  puts "#{e.class}: #{e.message}"
  
  # API error details
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API connection error: #{e.message}"
    if e.response
      puts "Response status: #{e.response[:status]}"
      puts "Response body: #{e.response[:body]}"
    end
  end
end