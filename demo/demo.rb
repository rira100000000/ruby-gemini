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
def print_conversation(messages, show_all = false, skip_system = true, character_name)
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
  
  # Generate response using system_instruction
  response = client.generate_content(
    initial_prompt,
    model: "gemini-2.0-flash", # Specify model name
    system_instruction: system_instruction
  )
  
  # Extract text from response
  if response["candidates"] && !response["candidates"].empty?
    model_text = response["candidates"][0]["content"]["parts"][0]["text"]
    
    # Add to conversation history
    conversation_history << { role: "user", content: initial_prompt }
    conversation_history << { role: "model", content: model_text }
    
    # Display response
    puts "[#{character_name}]: #{model_text}"
  else
    logger.error "Failed to generate response: #{response.inspect}"
  end
  
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
      print_conversation(conversation_history, true, false, character_name)
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
    
    # Generate response using system_instruction
    response = client.chat(parameters: {
      model: "gemini-2.0-flash", # Specify model name
      system_instruction: { parts: [{ text: system_instruction }] },
      contents: contents
    })
    
    logger.info "Generating response from Gemini..."
    
    # Extract text from response
    if response["candidates"] && !response["candidates"].empty?
      model_text = response["candidates"][0]["content"]["parts"][0]["text"]
      
      # Add to conversation history
      conversation_history << { role: "model", content: model_text }
      
      # Display response
      puts "[#{character_name}]: #{model_text}"
    else
      logger.error "Failed to generate response: #{response.inspect}"
      puts "[#{character_name}]: Sorry, I couldn't generate a response."
    end
  end
  
  logger.info "Ending conversation."

rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n")
end