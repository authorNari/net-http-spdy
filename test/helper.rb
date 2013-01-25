module TestNetHTTPSPDY
  extend Forwardable

  HANDLERS = %w(on_open on_ping on_headers on_settings
                on_body on_message_complete on_reset)

  def setup
    @parser = SPDY::Parser.new
    spawn_server
  end

  def teardown
    EM.stop_event_loop
    while @server_thread.alive?
      sleep 0.1
    end
  end

  def new
    http = Net::HTTP::SPDY.new(config('host'), config('port'))
    http.set_debug_output logfile()
    http
  end

  def config(key)
    @config ||= self.class::CONFIG
    @config[key]
  end

  def logfile
    $DEBUG ? $stderr : NullWriter.new
  end

  def start(&block)
    new.start(&block)
  end

  def_delegators "SPDYHandler", *HANDLERS
  def_delegators :@parser, :zlib_session

  private
  def unused_port
    s = TCPServer.open(0)
    port = s.addr[1]
    s.close
    port
  end

  def spawn_server
    @config = {'host' => '127.0.0.1', 'port' => unused_port}
    SPDYHandler.parser = @parser
    @server_thread = Thread.start do
      EM.run do
        EM.start_server(config('host'), config('port'), SPDYHandler)
      end
    end
    @server_thread.abort_on_exception = true
    n_try_max = 5
    begin
      TCPSocket.open(config('host'), config('port')).close
    rescue Errno::ECONNREFUSED
      sleep 0.2
      n_try_max -= 1
      raise 'cannot spawn server; give up' if n_try_max < 0
      retry
    end
  end

  class SPDYHandler < EM::Connection
    def self.parser=(parser)
      @@parser = parser
    end

    HANDLERS.each do |h|
      self.class_eval <<-METHOD
        @@#{h} = nil
        def self.#{h}(&block)
          @@#{h} = block
        end
      METHOD
    end

    def post_init
      HANDLERS.each do |h|
        if self.class.class_variable_get("@@#{h}")
          @@parser.send(h) do |*args|
            self.class.class_variable_get("@@#{h}").call(self, *args)
          end
        end
      end
    end

    def receive_data(data)
      @@parser << data if not data.empty?
    end
  end

  class NullWriter
    def <<(s) end
    def puts(*args) end
    def print(*args) end
    def printf(*args) end
  end
end
