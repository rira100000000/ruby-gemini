[README ‐ 日本語](https://github.com/rira100000000/ruby-gemini/wiki/README-%E2%80%90-%E6%97%A5%E6%9C%AC%E8%AA%9E)
# Ruby-Gemini

A Ruby client library for Google's Gemini API. This gem provides a simple, intuitive interface for interacting with Gemini's generative AI capabilities, following patterns similar to other AI client libraries.

This project is inspired by and pays homage to [ruby-openai](https://github.com/alexrudall/ruby-openai), aiming to provide a familiar and consistent experience for Ruby developers working with Gemini's AI models.

## Features

- Text generation with Gemini models
- Chat functionality with conversation history
- Streaming responses for real-time text generation
- Audio transcription capabilities
- Thread and message management for chat applications
- Runs management for executing AI tasks
- Convenient Response object for easy access to generated content

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby-gemini'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install ruby-gemini
```

## Quick Start

### Text Generation

```ruby
require 'gemini'

# Initialize client with API key
client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Generate text
response = client.generate_content(
  "What are the main features of Ruby programming language?",
  model: "gemini-2.0-flash-lite"
)

# Access the generated content using Response object
if response.valid?
  puts response.text
else
  puts "Error: #{response.error}"
end
```

### Streaming Text Generation

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Stream response in real-time
client.generate_content_stream(
  "Tell me a story about a programmer who loves Ruby",
  model: "gemini-2.0-flash-lite"
) do |chunk|
  print chunk
  $stdout.flush
end
```

### Chat Conversations

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Create conversation contents
contents = [
  { role: "user", parts: [{ text: "Hello, I'm interested in learning Ruby." }] },
  { role: "model", parts: [{ text: "That's great! Ruby is a dynamic, interpreted language..." }] },
  { role: "user", parts: [{ text: "What makes Ruby different from other languages?" }] }
]

# Get response with conversation history
response = client.chat(parameters: {
  model: "gemini-2.0-flash-lite",
  contents: contents
})

# Process the response using Response object
if response.success?
  puts response.text
else
  puts "Error: #{response.error}"
end

# You can also access other response information
puts "Finish reason: #{response.finish_reason}"
puts "Token usage: #{response.total_tokens}"
```

### Using System Instructions

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Set system instructions for model behavior
system_instruction = "You are a Ruby programming expert who provides concise code examples."

# Use system instructions with chat
response = client.chat(parameters: {
  model: "gemini-2.0-flash-lite",
  system_instruction: { parts: [{ text: system_instruction }] },
  contents: [{ role: "user", parts: [{ text: "How do I write a simple web server in Ruby?" }] }]
})

# Access the response
puts response.text

# Check if the response was blocked for safety reasons
if response.safety_blocked?
  puts "Response was blocked due to safety considerations"
end
```

### Image Recognition

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Analyze an image file (note: file size limit is 20MB for direct upload)
response = client.generate_content(
  [
    { type: "text", text: "Describe what you see in this image" },
    { type: "image_file", image_file: { file_path: "path/to/image.jpg" } }
  ],
  model: "gemini-2.0-flash"
)

# Access the description using Response object
if response.success?
  puts response.text
else
  puts "Image analysis failed: #{response.error}"
end
```

For image files larger than 20MB, you should use the `files.upload` method:

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Upload large image file
file = File.open("path/to/large_image.jpg", "rb")
upload_result = client.files.upload(file: file)
# Get file uri and name from the response
file_uri = upload_result["file"]["uri"]
file_name = upload_result["file"]["name"]

# Use the file URI for image analysis
response = client.generate_content(
  [
    { text: "Describe this image in detail" },
    { file_data: { mime_type: "image/jpeg", file_uri: file_uri } }
  ],
  model: "gemini-2.0-flash"
)

# Process the response using Response object
if response.success?
  puts response.text
else
  puts "Image analysis failed: #{response.error}"
end

# Optionally delete the file when done
client.files.delete(name: file_name)
```

For more examples, check out the `demo/vision_demo.rb` and `demo/file_vision_demo.rb` files included with the gem.

### Image Generation

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Generate an image using Gemini 2.0
response = client.images.generate(
  parameters: {
    prompt: "A beautiful sunset over the ocean with sailing boats",
    model: "gemini-2.0-flash-exp-image-generation",
    size: "16:9"
  }
)

# Save the generated image
if response.success? && !response.images.empty?
  filepath = "generated_image.png"
  response.save_image(filepath)
  puts "Image saved to #{filepath}"
else
  puts "Image generation failed: #{response.error}"
end
```

You can also use Imagen 3 model (Note: This feature is not fully tested yet):

```ruby
# Generate multiple images using Imagen 3
response = client.images.generate(
  parameters: {
    prompt: "A futuristic city with flying cars and tall skyscrapers",
    model: "imagen-3.0-generate-002",
    size: "1:1",
    n: 4  # Generate 4 images
  }
)

# Save all generated images
if response.success? && !response.images.empty?
  filepaths = response.images.map.with_index { |_, i| "imagen_#{i+1}.png" }
  saved_files = response.save_images(filepaths)
  saved_files.each { |f| puts "Image saved to #{f}" if f }
end
```

For a complete example, check out the `demo/image_generation_demo.rb` file included with the gem.

### Audio Transcription

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Transcribe audio file (note: file size limit is 20MB for direct upload)
response = client.audio.transcribe(
  parameters: {
    model: "gemini-1.5-flash",
    file: File.open("audio_file.mp3", "rb"),
    language: "en",
    content_text: "Transcribe this audio clip"
  }
)

# Response object makes accessing the transcription easy
if response.success?
  puts response.text
else
  puts "Transcription failed: #{response.error}"
end
```

For audio files larger than 20MB, you should use the `files.upload` method:

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Upload large audio file
file = File.open("path/to/audio.mp3", "rb")
upload_result = client.files.upload(file: file)
# Get file uri and name from the response
file_uri = upload_result["file"]["uri"]
file_name = upload_result["file"]["name"]

# Use the file ID for transcription
response = client.audio.transcribe(
  parameters: {
    model: "gemini-1.5-flash",
    file_uri: file_uri,
    language: "en"
  }
)

# Check if the response was successful and get the transcription
if response.success?
  puts response.text
else
  puts "Transcription failed: #{response.error}"
end

# Optionally delete the file when done
client.files.delete(name: file_name)
```

For more examples, check out the `demo/file_audio_demo.rb` file included with the gem.

## Advanced Usage

### Threads and Messages

The library supports a threads and messages concept similar to other AI platforms:

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Create a new thread
thread = client.threads.create(parameters: { model: "gemini-2.0-flash-lite" })
thread_id = thread["id"]

# Add a message to the thread
message = client.messages.create(
  thread_id: thread_id,
  parameters: {
    role: "user",
    content: "Tell me about Ruby on Rails"
  }
)

# Execute a run on the thread
run = client.runs.create(thread_id: thread_id)

# Retrieve all messages in the thread
messages = client.messages.list(thread_id: thread_id)
puts "\nAll messages in thread:"
messages["data"].each do |msg|
  role = msg["role"]
  content = msg["content"].map { |c| c["text"]["value"] }.join("\n")
  puts "#{role.upcase}: #{content}"
end
```

### Working with Response Objects

The Response object provides several useful methods for working with API responses:

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

response = client.generate_content(
  "Tell me about the Ruby programming language",
  model: "gemini-2.0-flash-lite"
)

# Basic response information
puts "Valid response? #{response.valid?}"
puts "Success? #{response.success?}"

# Access text content
puts "Text: #{response.text}"
puts "Formatted text: #{response.formatted_text}"

# Get individual text parts
puts "Text parts: #{response.text_parts.size}"
response.text_parts.each_with_index do |part, i|
  puts "Part #{i+1}: #{part[0..30]}..." # Print beginning of each part
end

# Access first candidate
puts "First candidate role: #{response.role}"

# Token usage information
puts "Prompt tokens: #{response.prompt_tokens}"
puts "Completion tokens: #{response.completion_tokens}"
puts "Total tokens: #{response.total_tokens}"

# Safety information
puts "Finish reason: #{response.finish_reason}"
puts "Safety blocked? #{response.safety_blocked?}"

# Raw data access for advanced needs
puts "Raw response data available? #{!response.raw_data.nil?}"
```

### Configuration

Configure the client with custom options:

```ruby
require 'gemini'

# Global configuration
Gemini.configure do |config|
  config.api_key = ENV['GEMINI_API_KEY']
  config.uri_base = "https://generativelanguage.googleapis.com/v1beta"
  config.request_timeout = 60
  config.log_errors = true
end

# Or per-client configuration
client = Gemini::Client.new(
  ENV['GEMINI_API_KEY'],
  {
    uri_base: "https://generativelanguage.googleapis.com/v1beta",
    request_timeout: 60,
    log_errors: true
  }
)

# Add custom headers
client.add_headers({"X-Custom-Header" => "value"})
```

## Demo Applications

The gem includes several demo applications that showcase its functionality:

- `demo/demo.rb` - Basic text generation and chat
- `demo/stream_demo.rb` - Streaming text generation
- `demo/audio_demo.rb` - Audio transcription
- `demo/vision_demo.rb` - Image recognition
- `demo/image_generation_demo.rb` - Image generation 
- `demo/file_vision_demo.rb` - Image recognition with large image files
- `demo/file_audio_demo.rb` - Audio transcription with large audio files
Run the demos with:

Adding _ja to the name of each demo file will launch the Japanese version of the demo.
example: `ruby demo_ja.rb`

```bash
# Basic chat demo
ruby demo/demo.rb

# Streaming chat demo
ruby demo/stream_demo.rb

# Audio transcription
ruby demo/audio_demo.rb path/to/audio/file.mp3

# Audio transcription with over 20MB audio file
ruby demo/file_audio_demo.rb path/to/audio/file.mp3

# Image recognition
ruby demo/vision_demo.rb path/to/image/file.jpg

# Image recognition with large image files
ruby demo/file_vision_demo.rb path/to/image/file.jpg

# Image generation
ruby demo/image_generation_demo.rb
```

## Models

The library supports various Gemini models:

- `gemini-2.0-flash-lite`
- `gemini-2.0-flash`
- `gemini-2.0-pro`
- `gemini-1.5-flash`

## Requirements

- Ruby 3.0 or higher
- Faraday 2.0 or higher
- Google Gemini API key

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).