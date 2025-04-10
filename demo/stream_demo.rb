require 'bundler/setup'
require 'gemini'  # load gemini library
require 'logger'
require 'readline' # for command line editing features

# Logger configuration
logger = Logger.new(STDOUT)
logger.level = Logger::WARN

# Get API key from environment variable or specify directly
api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
character_name = "Molsuke"

# System instruction (prompt)
system_instruction = "You are a cute guinea pig named Molsuke. Please add 'mol' at the end of your sentences and act cute. Your responses should be easy to understand and within 300 characters."

# Conversation history
conversation_history = []

# Function to display the conversation progress
def print_conversation(messages, show_all = false, character_name)
  puts "\n=== Conversation History ==="
  
  # Messages to display
  display_messages = show_all ? messages : [messages.last].compact
  
  display_messages.each do |message|
    role = message[:role]
    content = message[:content]
    
    if role == "user"
      puts "[User]: " + content
    else
      puts "[#{character_name}]: " + content
    end
  end
  
  puts "===============\n"
end

# Command completion settings
COMMANDS = ['exit', 'history', 'help', 'all'].freeze
Readline.completion_proc = proc { |input|
  COMMANDS.grep(/^#{Regexp.escape(input)}/)
}

# Safely extract text from chunk
def extract_text_from_chunk(chunk)
  # If chunk is a hash (parsed as JSON)
  if chunk.is_a?(Hash) && chunk.dig("candidates", 0, "content", "parts", 0, "text")
    return chunk.dig("candidates", 0, "content", "parts", 0, "text")
  # If chunk is a string
  elsif chunk.is_a?(String)
    return chunk
  # Otherwise return empty string
  else
    return ""
  end
end

# Main process
begin
  # Initialize client
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "\nStarting conversation with #{character_name}."
  puts "Commands:"
  puts "  exit    - End conversation"
  puts "  history - Display conversation history"
  puts "  all     - Display all conversation history"
  puts "  help    - Display this help"
  
  # Generate initial message (conversation greeting)
  initial_prompt = "Hello, please introduce yourself."
  logger.info "Sending initial message..."
  
  # Generate initial response (streaming format)
  print "[#{character_name}]: "
  
  # Use streaming callback
  response_text = ""
  
  client.generate_content_stream(
    initial_prompt,
    model: "gemini-2.0-flash", # Specify model name
    system_instruction: system_instruction
  ) do |chunk|
    # Safely extract text from chunk
    chunk_text = extract_text_from_chunk(chunk)
    
    if chunk_text.to_s.strip.empty?
      next  # Skip empty chunks
    else
      print chunk_text
      $stdout.flush
      response_text += chunk_text
    end
  end
  
  puts "\n"
  
  # Add to conversation history
  conversation_history << { role: "user", content: initial_prompt }
  conversation_history << { role: "model", content: response_text }
  
  # Conversation loop
  while true
    # Get user input using Readline (with history and editing features)
    user_input = Readline.readline("> ", true)
    
    # If input is nil (Ctrl+D was pressed)
    if user_input.nil?
      puts "\nEnding conversation."
      break
    end
    
    user_input = user_input.strip
    
    # Exit command
    if user_input.downcase == 'exit'
      puts "Ending conversation."
      break
    end
    
    # Help display
    if user_input.downcase == 'help'
      puts "\nCommands:"
      puts "  exit    - End conversation"
      puts "  history - Display conversation history"
      puts "  all     - Display all conversation history"
      puts "  help    - Display this help"
      next
    end
    
    # History display command
    if user_input.downcase == 'history' || user_input.downcase == 'all'
      print_conversation(conversation_history, true, character_name)
      next
    end
    
    # Skip empty input
    if user_input.empty?
      next
    end
    
    # Add user input to conversation history
    conversation_history << { role: "user", content: user_input }
    logger.info "Sending message..."
    
    # Build contents from conversation history
    contents = conversation_history.map do |msg|
      {
        role: msg[:role] == "user" ? "user" : "model",
        parts: [{ text: msg[:content] }]
      }
    end
    
    # Generate response (streaming format)
    logger.info "Generating response from Gemini..."
    print "[#{character_name}]: "
    
    # Use streaming callback
    response_text = ""
    response_received = false
    
    # Generate streaming response using system_instruction
    begin
      client.chat(parameters: {
        model: "gemini-2.0-flash", # Specify model name
        system_instruction: { parts: [{ text: system_instruction }] },
        contents: contents,
        stream: proc do |chunk, _raw_chunk|
          # Safely extract text from chunk
          chunk_text = extract_text_from_chunk(chunk)
          
          if chunk_text.to_s.strip.empty?
            next  # Skip empty chunks
          else
            response_received = true
            print chunk_text
            $stdout.flush
            response_text += chunk_text
          end
        end
      })
    rescue => e
      logger.error "Error occurred during streaming: #{e.message}"
      puts "\nError occurred during streaming. Attempting normal response."
      
      # Try normal response
      begin
        response = client.chat(parameters: {
          model: "gemini-2.0-flash",
          system_instruction: { parts: [{ text: system_instruction }] },
          contents: contents
        })
        
        if response["candidates"] && !response["candidates"].empty?
          model_text = response["candidates"][0]["content"]["parts"][0]["text"]
          puts model_text
          response_text = model_text
          response_received = true
        end
      rescue => e2
        logger.error "Error occurred with normal response as well: #{e2.message}"
      end
    end
    
    puts "\n"
    
    # Add response to conversation history if received
    if response_received && !response_text.empty?
      conversation_history << { role: "model", content: response_text }
      logger.info "Response generated"
    else
      logger.error "Failed to generate response"
      puts "[#{character_name}]: Sorry, I couldn't generate a response."
    end
  end
  
  logger.info "Ending conversation."

rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n")
end