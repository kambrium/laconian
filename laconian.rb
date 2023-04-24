require 'date'
require 'socket'

server = TCPServer.new 'localhost', 1965

loop do
  Thread.start(server.accept) do |client|
    request = client.gets
    puts "#{DateTime.now} #{request}"

    client.puts("2 text/gemini\r\n")
    file_stream = File.new('index.gmi', 'rb')
    IO::copy_stream(file_stream, client)
    file_stream.close
    
    client.close
  end
end