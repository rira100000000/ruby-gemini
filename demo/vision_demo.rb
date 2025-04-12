# Example of asking questions using an image URL
require 'bundler/setup'
require 'gemini'
require 'logger'

# Logger configuration
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable or direct specification
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)

  puts "Gemini Vision API Demo"
  puts "==================================="
  
  # Specify the path to the image file
  image_file_path = ARGV[0] || raise("Usage: ruby vision_demo_en.rb <path to image file>")
  
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
  puts "==================================="
  
  # Start time
  start_time = Time.now

  # Load image from local file
  response = client.generate_content(
    [
      { 
        type: "text", 
        text: "Please describe what you see in this image"
      },
      { 
        type: "image_file", 
        image_file: { 
          file_path: image_file_path
        } 
      }
    ],
    model: "gemini-2.0-flash"
  )

  # End time and elapsed time calculation
  end_time = Time.now
  elapsed_time = end_time - start_time

  # Display results using Response class methods
  puts "\n=== Image Analysis Result ==="
  if response.success?
    puts response.text
    
    # Display token usage information (if available)
    if response.usage && !response.usage.empty?
      puts "\nToken usage:"
      puts "Prompt tokens: #{response.prompt_tokens}"
      puts "Generation tokens: #{response.completion_tokens}"
      puts "Total tokens: #{response.total_tokens}"
    end
    
    # Display safety filter results (if present)
    if !response.safety_ratings.empty?
      puts "\nSafety ratings:"
      response.safety_ratings.each do |rating|
        puts "Category: #{rating['category']}, Level: #{rating['probability']}"
      end
    end
  else
    puts "An error occurred: #{response.error || 'Unknown error'}"
  end
  
  puts "==================================="
  puts "Processing time: #{elapsed_time.round(2)} seconds"

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