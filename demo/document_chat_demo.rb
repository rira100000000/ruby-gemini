require 'bundler/setup'
require 'gemini'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Document Chat Demo"
  puts "==================================="
  
  # Specify document file path
  document_path = ARGV[0] || raise("Usage: ruby document_chat_demo_en.rb <document_file_path> [prompt]")
  
  # Specify prompt
  prompt = ARGV[1] || "Please summarize this document in three key points"
  
  # Check if file exists
  unless File.exist?(document_path)
    raise "File not found: #{document_path}"
  end
  
  # Display file information
  file_size = File.size(document_path) / 1024.0 # Size in KB
  file_extension = File.extname(document_path)
  puts "File: #{File.basename(document_path)}"
  puts "Size: #{file_size.round(2)} KB"
  puts "Type: #{file_extension}"
  puts "Prompt: #{prompt}"
  puts "==================================="
  
  # Start time
  start_time = Time.now
  
  # Choose processing method (default: use Documents class)
  use_direct_approach = ENV['USE_DIRECT'] == 'true'
  
  puts "Processing method: #{use_direct_approach ? 'Using API directly' : 'Using Documents class'}"
  puts "Processing document..."
  
  if use_direct_approach
    # Method using API directly
    result = client.upload_and_process_file(document_path, prompt)
    response = result[:response]
  else
    # Method using Documents class
    result = client.documents.process(file_path: document_path, prompt: prompt)
    response = result[:response]
  end
  
  # End time and elapsed time calculation
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  puts "\n=== Document Processing Results ==="
  
  if response.success?
    puts response.text
  else
    puts "Error: #{response.error || 'Unknown error'}"
  end
  
  puts "======================="
  puts "Processing time: #{elapsed_time.round(2)} seconds"
  
  # File information
  puts "File URI: #{result[:file_uri]}"
  puts "File name: #{result[:file_name]}"
  
  # Token usage information (if available)
  if response.total_tokens > 0
    puts "\nToken usage:"
    puts "  Prompt: #{response.prompt_tokens}"
    puts "  Generation: #{response.completion_tokens}"
    puts "  Total: #{response.total_tokens}"
  end

rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
end