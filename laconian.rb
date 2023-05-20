# Laconian - A simple Spartan static file server
#
# Laconian is a Ruby port of the Spartan reference server on 
# https://github.com/michael-lazar/spartan/blob/main/public/spartan_server.py.

require 'bundler/setup'
require 'cgi'
require 'date'
require 'mime/types'
require 'optparse'
require 'socket'

class SpartanRequestHandler
  attr_reader :client

  def initialize(client)
    @client = client
  end

  def handle(directory)
    request = @client.gets
    puts "#{DateTime.now} #{request}"
    hostname, path, content_length = request.split(" ")
    if !path
      raise IOError.new("Not found")
    end

    path = CGI.unescape(path)

    # Guard against breaking out of the directory. Source (accessed 23-05-10):
    # https://practicingruby.com/articles/implementing-an-http-file-server
    clean = []
    parts = path.split("/")
    parts.each do |part|
      next if part.empty? || part == "."
      part == ".." ? clean.pop : clean << part
    end

    file_path = File.join(directory, *clean)

    if File.file?(file_path)
      write_file(file_path)
    elsif File.directory?(file_path)
      if !path.end_with?("/")
        write_status(3, "#{path}/")
      elsif File.file?(File.join(file_path, "index.gmi"))
        write_file(File.join(file_path, "index.gmi"))
      else
        write_status(2, "text/gemini")
        write_line("=>..")
        Dir.each_child(file_path) do |child|
          if File.directory?(File.join(file_path, child)) # Can be improved?
            write_line("#{child}/")
          else
            write_line("#{child}")
          end
        end
      end
    else
      raise IOError.new("Not found")
    end

  rescue IOError => e
    write_status(4, e)
  rescue
    write_status(5, "An unexpected error has occurred")
    raise
  end

  def write_line(text)
    @client.puts("#{text}\n")
  end

  def write_status(code, meta)
    @client.puts("#{code} #{meta}\r\n")
  end

  def write_file(file_path)
    mime_type = MIME::Types.type_for(File.extname(file_path)).first # Can be improved?
    write_status(2, mime_type)
    file_stream = File.new(file_path, 'rb')
    IO::copy_stream(file_stream, @client)
    file_stream.close
  end
end

options = { directory: ".", host: "localhost", port: "3000" }
OptionParser.new do |opt|
  opt.on("-d", "--directory DIRECTORY") { |o| options[:directory] = o }
  opt.on("-s", "--host HOST") { |o| options[:host] = o }
  opt.on("-p", "--port PORT") { |o| options[:port] = o }
end.parse!

server = TCPServer.new options[:host], options[:port]

text_gemini = MIME::Type.new(["text/gemini", "gmi"])
MIME::Types.add(text_gemini)

loop do
  Thread.start(server.accept) do |client|
    srh = SpartanRequestHandler.new(client)
    srh.handle(options[:directory])
    client.close
  end
end