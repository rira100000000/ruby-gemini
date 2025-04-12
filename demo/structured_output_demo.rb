require 'bundler/setup'
require 'gemini'
require 'json'
require 'pp'

api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  puts "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Structured Output Demo"
  puts "==================================="

  # Request JSON response by directly specifying the schema
  # Define recipe schema
  recipe_schema = {
    type: "ARRAY",
    items: {
      type: "OBJECT",
      properties: {
        "recipe_name": { type: "STRING" },
        "ingredients": {
          type: "ARRAY",
          items: { type: "STRING" }
        },
        "preparation_time": {
          type: "INTEGER",
          description: "Preparation time (minutes)"
        }
      },
      required: ["recipe_name", "ingredients"],
      propertyOrdering: ["recipe_name", "ingredients", "preparation_time"]
    }
  }
  
  response = client.generate_content(
    "Introduce three popular cookie recipes. Include the name, ingredients, and preparation time for each recipe.",
    response_mime_type: "application/json",
    response_schema: recipe_schema
  )
  
  if response.success? && response.json?
    puts "JSON response:"
    pp response.json
    
    # Example of utilizing the response structure
    puts "\nSorting recipes by preparation time (shortest first):"
    sorted_recipes = response.json.sort_by { |recipe| recipe["preparation_time"] || Float::INFINITY }
    sorted_recipes.each do |recipe|
      prep_time = recipe["preparation_time"] ? "#{recipe["preparation_time"]} minutes" : "time unknown"
      puts "#{recipe["recipe_name"]} (#{prep_time})"
      puts "  Ingredients: #{recipe["ingredients"].join(", ")}" if recipe["ingredients"]
      puts
    end
  else
    puts "Failed to get JSON: #{response.error || 'Unknown error'}"
    puts "Text response:"
    puts response.text
  end
  
  puts "\n==================================="
  puts "Demo completed"

rescue StandardError => e
  puts "\nAn error occurred: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end