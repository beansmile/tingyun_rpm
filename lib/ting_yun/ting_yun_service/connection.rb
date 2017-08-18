# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


module TingYun
  class TingYunService
    module Connection
      # Return a Net::HTTP connection object to make a call to the collector.
      # We'll reuse the same handle for cases where we're using keep-alive, or
      # otherwise create a new one.



      def http_connection
        if @in_session
          establish_shared_connection
        else
          create_http_connection
        end
      end

      def establish_shared_connection
        unless @shared_tcp_connection
          @shared_tcp_connection = create_and_start_http_connection
        end
        @shared_tcp_connection
      end


      def create_and_start_http_connection
        conn = create_http_connection
        start_connection(conn)
        conn
      end

      def start_connection(conn)
        TingYun::Agent.logger.debug("Opening TCP connection to #{conn.address}:#{conn.port}")
        TingYun::Support::TimerLib.timeout(@request_timeout) { conn.start }
        conn
      end


      def create_http_connection
        if TingYun::Agent.config[:proxy_host]
          TingYun::Agent.logger.debug("Using proxy server #{TingYun::Agent.config[:proxy_host]}:#{TingYun::Agent.config[:proxy_port]}")

          proxy = Net::HTTP::Proxy(
              TingYun::Agent.config[:proxy_host],
              TingYun::Agent.config[:proxy_port],
              TingYun::Agent.config[:proxy_user],
              TingYun::Agent.config[:proxy_pass]
          )
          conn = proxy.new(@collector.name, @collector.port)
        else
          conn = Net::HTTP.new(@collector.name, @collector.port)
        end

        setup_connection_for_ssl(conn) if TingYun::Agent.config[:ssl]
        setup_connection_timeouts(conn)
        TingYun::Agent.logger.debug("Created net/http handle to #{conn.address}:#{conn.port}")

        conn
      end

      def close_shared_connection
        if @shared_tcp_connection
          TingYun::Agent.logger.debug("Closing shared TCP connection to #{@shared_tcp_connection.address}:#{@shared_tcp_connection.port}")
          @shared_tcp_connection.finish if @shared_tcp_connection.started?
          @shared_tcp_connection = nil
        end
      end


      def setup_connection_timeouts(conn)
        # We use Timeout explicitly instead of this
        conn.read_timeout = nil

        if conn.respond_to?(:keep_alive_timeout) && TingYun::Agent.config[:aggressive_keepalive]
          conn.keep_alive_timeout = TingYun::Agent.config[:keep_alive_timeout]
        end
      end

      # One session with the service's endpoint.  In this case the session
      # represents 1 tcp connection which may transmit multiple HTTP requests
      # via keep-alive.
      def session(&block)
        raise ArgumentError, "#{self.class}#shared_connection must be passed a block" unless block_given?

        begin
          t0 = Time.now
          @in_session = true
          if TingYun::Agent.config[:aggressive_keepalive]
            session_with_keepalive(&block)
          else
            session_without_keepalive(&block)
          end
        rescue *CONNECTION_ERRORS => e
          elapsed = Time.now - t0
          raise TingYun::Support::Exception::ServerConnectionException, "Recoverable error connecting to #{@collector} after #{elapsed} seconds: #{e}"
        ensure
          @in_session = false
        end
      end

      def session_with_keepalive(&block)
        establish_shared_connection
        block.call
      end

      def session_without_keepalive(&block)
        begin
          establish_shared_connection
          block.call
        ensure
          close_shared_connection
        end
      end

    end
  end
end