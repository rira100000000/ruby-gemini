require 'bundler/setup'
require 'gemini'
require 'logger'

# Logger configuration
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Save API response
SAVE_RESPONSE = false

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY environment variable is not set")

# Helper method to truncate Base64 data for display
def deep_clone_and_truncate_base64(obj, max_length = 20)
  case obj
  when Hash
    result = {}
    obj.each do |k, v|
      # Truncate content of "data" or "bytesBase64Encoded" keys
      if (k == "data" || k == "bytesBase64Encoded") && v.is_a?(String) && v.length > max_length
        result[k] = "#{v[0...max_length]}...[Base64 data #{v.length} bytes]"
      else
        result[k] = deep_clone_and_truncate_base64(v, max_length)
      end
    end
    result
  when Array
    obj.map { |item| deep_clone_and_truncate_base64(item, max_length) }
  else
    obj
  end
end

begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Image Generation Demo"
  puts "==================================="
  
  # Get prompt from user
  puts "Please enter a prompt for image generation:"
  prompt = gets.chomp
  
  if prompt.empty?
    # Default prompt
    prompt = "Beautiful Japanese cherry blossom tree under a blue sky"
    puts "No prompt entered. Using default prompt: \"#{prompt}\""
  end
  
  puts "\nSelect a model to use:"
  puts "1. Gemini 2.0 (gemini-2.0-flash-exp-image-generation)"
  puts "2. Imagen 3 (imagen-3.0-generate-002) [Note: Not yet fully tested with this demo]"
  model_choice = gets.chomp.to_i
  model = case model_choice
          when 2
            "imagen-3.0-generate-002"
          else
            "gemini-2.0-flash-exp-image-generation"
          end

  puts "\nSelect image size:"
  puts "1. Square (1:1)"
  puts "2. Portrait (3:4)"
  puts "3. Landscape (4:3)"
  puts "4. Tall (9:16)"
  puts "5. Wide (16:9)"

  size_choice = gets.chomp.to_i
  size = case size_choice
         when 2
           "3:4"
         when 3
           "4:3"
         when 4
           "9:16"
         when 5
           "16:9"
         else
           "1:1"
         end

  # For Imagen 3, number of images can be specified
  sample_count = 1
  if model.start_with?("imagen")
    puts "\nSpecify the number of images to generate (1-4):"
    sample_count = gets.chomp.to_i
    sample_count = [[sample_count, 1].max, 4].min # Limit to range 1-4
  end

  # Setup output filenames
  timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  output_dir = "generated_images"
  Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

  # Start time
  start_time = Time.now

  puts "\nGenerating images..."

  # Generate images using Images API
  response = client.images.generate(
    parameters: {
      prompt: prompt,
      model: model,
      size: size,
      n: sample_count
    }
  )

  # End time and elapsed time calculation
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  # Save API response to file
  if SAVE_RESPONSE
    response_dir = "api_responses"
    Dir.mkdir(response_dir) unless Dir.exist?(response_dir)
    response_file = File.join(response_dir, "response_#{timestamp}.json")
    
    File.open(response_file, 'w') do |f|
      f.write(JSON.pretty_generate(response.raw_data))
    end
    
    puts "\nAPI response saved to: #{response_file}"
  end
  if response.success?
    # Debug output response details (with truncated Base64 data)
    if ENV["DEBUG"]
      puts "\nResponse data structure:"
      # Create deep copy with truncated Base64 data for display
      truncated_response = deep_clone_and_truncate_base64(response.raw_data)
      pp truncated_response
    end
    
    # Check image data
    if !response.images.empty?
      puts "\nImage generation successful!"
      
      # Save generated images to files
      filepaths = response.images.map.with_index do |_, i|
        File.join(output_dir, "#{timestamp}_#{i+1}.png")
      end
      
      saved_files = response.save_images(filepaths)
      
      puts "\nSaved image files:"
      saved_files.each do |filepath|
        if filepath
          puts "- #{filepath}"
        else
          puts "- Failed to save an image"
        end
      end
    else
      puts "\nNo image data found. Maybe only text response was generated."
    end
    
    # Display text response if available
    if response.text && !response.text.empty?
      puts "\nMessage from the model:"
      puts response.text
    end
  else
    puts "\nImage generation failed: #{response.error || 'Unknown error'}"
    # Display detailed error information
    puts "Detailed response information:"
    pp response.raw_data
  end

  puts "\nProcessing time: #{elapsed_time.round(2)} seconds"

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