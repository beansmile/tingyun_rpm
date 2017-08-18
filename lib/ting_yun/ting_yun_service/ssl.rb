# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/support/path'
require 'ting_yun/support/exception'

module TingYun
  class TingYunService
    module Ssl

      def setup_connection_for_ssl(conn)
        # Jruby 1.6.8 requires a gem for full ssl support and will throw
        # an error when use_ssl=(true) is called and jruby-openssl isn't
        # installed
        conn.use_ssl     = true
        conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
        conn.cert_store  = ssl_cert_store
      rescue StandardError, LoadError
        msg = "Agent is configured to use SSL, but SSL is not available in the environment. "
        msg << "Either disable SSL in the agent configuration, or install SSL support."
        raise TingYun::Support::Exception::UnrecoverableAgentException.new(msg)
      end

      def ssl_cert_store
        path = cert_file_path
        if !@ssl_cert_store || path != @cached_cert_store_path
          TingYun::Agent.logger.debug("Creating SSL certificate store from file at #{path}")
          @ssl_cert_store = OpenSSL::X509::Store.new
          @ssl_cert_store.add_file(path)
          @cached_cert_store_path = path
        end
        @ssl_cert_store
      end

      def cert_file_path
        if path_override = TingYun::Agent.config[:ca_bundle_path]
          TingYun::Agent.logger.warn("Couldn't find CA bundle from configured ca_bundle_path: #{path_override}") unless File.exist? path_override
          path_override
        else
          File.expand_path(File.join(TingYun::Support::Path.ting_yun_root, 'cert', 'cacert.pem'))
        end
      end

    end
  end
end