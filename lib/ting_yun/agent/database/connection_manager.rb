# encoding: utf-8

module TingYun
  module Agent
    module Database
      # Returns a cached connection for a given ActiveRecord
      # configuration - these are stored or reopened as needed, and if
      # we cannot get one, we ignore it and move on without explaining
      # the sql
      class ConnectionManager
        include Singleton

        def get_connection(config, &connector)
          @connections ||= {}

          connection = @connections[config]

          return connection if connection

          begin
            @connections[config] = connector.call(config)
          rescue => e
            ::TingYun::Agent.logger.error("Caught exception trying to get connection to DB for explain.", e)
            nil
          end
        end

        # Closes all the connections in the internal connection cache
        def close_connections
          @connections ||= {}
          @connections.values.each do |connection|
            begin
              connection.disconnect!
            rescue
            end
          end

          @connections = {}
        end
      end

    end
  end
end