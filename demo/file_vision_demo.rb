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
  
  puts "Image Recognition Demo using File API (with Response support)"
  puts "==============================================="
  
  # Specify the path to the image file
  image_file_path = ARGV[0] || raise("Usage: ruby file_vision_demo_en.rb <path to image file>")
  
  # Check if file exists
  unless File.exist?(image_file_path)
    raise "File not found: #{image_file_path}"
  end
  
  # Display file information
  file_size = File.size(image_file_path) / 1024.0 # Size in KB
  file_extension = File.extname(image_file_path)
  puts "File: #{File.basename(image_file_path)}"
  puts "Size: #{file_size.round(2)} KB"
  puts "Type: #{file_extension}"
  puts "==============================================="
  
  # Determine MIME type
  mime_type = case file_extension.downcase
              when ".jpg", ".jpeg"
                "image/jpeg"
              when ".png"
                "image/png"
              when ".gif"
                "image/gif"
              when ".webp"
                "image/webp"
              else
                "image/jpeg" # Default
              end
  
  # Start time
  start_time = Time.now
  
  # Upload the file
  logger.info "Uploading image file..."
  puts "Uploading..."
  
  # Check client information
  puts "Client information:"
  puts "URI Base: #{client.uri_base}"
  
  file = File.open(image_file_path, "rb")
  begin
    # Upload process
    puts "Starting file upload process..."
    upload_result = client.files.upload(file: file)
    
    # Processing when successful
    file_uri = upload_result["file"]["uri"]
    file_name = upload_result["file"]["name"]
    
    puts "File uploaded:"
    puts "File URI: #{file_uri}"
    puts "File Name: #{file_name}"
    
    # Execute image analysis
    logger.info "Executing analysis of uploaded image..."
    puts "Analyzing image..."
    
    # Add retry logic (to counter 503 errors)
    max_retries = 3
    retry_count = 0
    retry_delay = 2 # Initial delay (seconds)
    
    begin
      # Implementation corresponding to Response class
      response = client.generate_content(
        [
          { text: "Please describe in detail what you see in this image." },
          { file_data: { mime_type: mime_type, file_uri: file_uri } }
        ],
        model: "gemini-2.0-flash"
      )
      
      # Confirm Response object is returned
      unless response.is_a?(Gemini::Response)
        logger.warn "Response is not a Gemini::Response instance: #{response.class}"
      end
      
    rescue Faraday::ServerError => e
      retry_count += 1
      if retry_count <= max_retries
        puts "Server error occurred. Retrying in #{retry_delay} seconds... (#{retry_count}/#{max_retries})"
        sleep retry_delay
        # Exponential backoff (double the delay)
        retry_delay *= 2
        retry
      else
        raise e
      end
    end
    
    # End time and elapsed time calculation
    end_time = Time.now
    elapsed_time = end_time - start_time
    
    # Display results - using Response object methods
    puts "\n=== Image Analysis Result ==="
    if response.valid?
      puts response.text
    else
      puts "Failed to get response: #{response.error || 'Unknown error'}"
    end
    puts "======================="
    puts "Processing time: #{elapsed_time.round(2)} seconds"
    
    # Detailed information (for debugging)
    if ENV["DEBUG"] == "true" && response.valid?
      puts "\n=== Response Details ==="
      puts "Success: #{response.success?}"
      puts "Finish reason: #{response.finish_reason}"
      puts "Number of text parts: #{response.text_parts.size}"
      puts "======================="
    end
    
    # Display uploaded file information
    begin
      file_info = client.files.get(name: file_name)
      puts "\n=== File Information ==="
      puts "Name: #{file_info['name']}"
      puts "Display Name: #{file_info['displayName']}" if file_info['displayName']
      puts "MIME Type: #{file_info['mimeType']}" if file_info['mimeType']
      puts "Size: #{file_info['sizeBytes'].to_i / 1024.0} KB" if file_info['sizeBytes']
      puts "Creation date: #{Time.at(file_info['createTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['createTime']
      puts "Expiration date: #{Time.at(file_info['expirationTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['expirationTime']
      puts "URI: #{file_info['uri']}" if file_info['uri']
      puts "Status: #{file_info['state']}" if file_info['state']
      puts "======================="
    rescue => e
      puts "Failed to retrieve file information: #{e.message}"
    end
    
    puts "The file will be automatically deleted after 48 hours"
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