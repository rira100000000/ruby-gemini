require 'bundler/setup'
require 'gemini'  # load gemini library
require 'logger'

# Logger configuration
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Starting audio file transcription"
  puts "==================================="
  
  # Specify audio file path
  audio_file_path = ARGV[0] || raise("Usage: ruby audio_demo.rb <audio file path>")
  
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
  puts "==================================="
  
  # Process start time
  start_time = Time.now
  
  # Execute transcription
  logger.info "Uploading audio file and executing transcription..."
  puts "Processing..."
  
  # Open file
  file = File.open(audio_file_path, "rb")
  
  begin
    response = client.audio.transcribe(
      parameters: {
        model: "gemini-1.5-flash", # Specify Gemini model
        file: file,
        language: "ja", # Specify language (change as needed)
        content_text: "Please transcribe this audio."
      }
    )
  ensure
    # Always close the file
    file.close
  end
  
  # Process end time and elapsed time calculation
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  # Display results
  puts "\n=== Transcription Result ==="
  puts response["text"]
  puts "======================="
  puts "Processing time: #{elapsed_time.round(2)} seconds"
  
  # If you want to check the raw response
  # puts "\n=== Raw Response ==="
  # puts JSON.pretty_generate(response["raw_response"])
  
rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
  
  puts "\nDetailed error information:"
  puts "#{e.class}: #{e.message}"
  
  # API error details
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API connection error: #{e.message}"
  end
end