require 'bundler/setup'
require 'gemini'
require 'json'
require 'pp'

# Load API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  puts "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Enum Constraint Response Demo"
  puts "==================================="

  # Example 1: Simple enum constraint (weather forecast)
  puts "\nExample 1: Weather Forecast (Simple enum)"
  puts "---------------------------------"
  
  # Define weather forecast schema (constrain response using enum)
  weather_schema = {
    type: "OBJECT",
    properties: {
      "forecast": {
        type: "STRING",
        # Specify only allowed values with enum
        enum: ["Sunny", "Cloudy", "Rainy", "Snowy", "Foggy"]
      },
      "temperature": {
        type: "INTEGER",
        description: "Temperature (Celsius)"
      }
    },
    required: ["forecast", "temperature"]
  }
  
  response = client.generate_content(
    "Please provide a simple weather forecast for Tokyo tomorrow.",
    response_mime_type: "application/json",
    response_schema: weather_schema
  )
  
  if response.success? && response.json?
    puts "JSON response:"
    pp response.json
    
    # Example using the response
    forecast = response.json["forecast"]
    temp = response.json["temperature"]
    puts "\nTomorrow's weather in Tokyo is expected to be \"#{forecast}\" with a temperature of #{temp}°C."
  else
    puts "Failed to get JSON: #{response.error || 'Unknown error'}"
    puts "Text response: #{response.text}"
  end
  
  # Example 2: Product Review (Modified version)
  puts "\n\nExample 2: Product Review (Modified version)"
  puts "---------------------------------"
  
  # Modify product review schema
  review_schema = {
    type: "OBJECT",
    properties: {
      "product_name": { 
        type: "STRING" 
      },
      # Rating allows only 1-5 (treated as strings)
      "rating": {
        type: "STRING",
        enum: ["1", "2", "3", "4", "5"],
        description: "Rating from 1 to 5 (5 being the highest)"
      },
      # Recommendation level also chosen from enumerated values
      "recommendation": {
        type: "STRING",
        enum: ["Not recommended", "Neutral", "Recommended", "Highly recommended"],
        description: "Level of recommendation for the product"
      },
      "comment": { 
        type: "STRING" 
      }
    },
    required: ["product_name", "rating", "recommendation"]
  }
  
  response = client.generate_content(
    "Please create a brief review for the new smartphone 'GeminiPhone 15'.",
    response_mime_type: "application/json",
    response_schema: review_schema
  )
  
  if response.success? && response.json?
    puts "JSON response:"
    pp response.json
    
    # Example using the response
    review = response.json
    puts "\nProduct Review: #{review['product_name']}"
    puts "Rating: #{review['rating']}/5 (#{review['recommendation']})"
    puts "Comment: #{review['comment']}" if review['comment']
  else
    puts "Failed to get JSON: #{response.error || 'Unknown error'}"
    puts "Text response: #{response.text}"
  end

  puts "\n==================================="
  puts "Demo completed"

rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end