# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

module TingYun
  module Agent
    module Threading
      class AgentThread

        def self.create(label, &blk)
          TingYun::Agent.logger.debug("Creating Ting Yun thread: #{label}")
          wrapped_blk = Proc.new do
            begin
              blk.call
            rescue => e
              TingYun::Agent.logger.error("Thread #{label} exited with error", e)
            rescue Exception => e
              TingYun::Agent.logger.error("Thread #{label} exited with exception. Re-raising in case of interupt.", e)
              raise
            ensure
              TingYun::Agent.logger.debug("Exiting TingYun thread: #{label}")
            end
          end

          thread = backing_thread_class.new(&wrapped_blk)
          thread[:TingYun_label] = label
          thread
        end

        # Simplifies testing if we don't directly use ::Thread.list, so keep
        # the accessor for it here on AgentThread to use and stub.
        def self.list
          backing_thread_class.list
        end

        # To allow tests to swap out Thread for a synchronous alternative,
        # surface the backing class we'll use from the class level.
        @backing_thread_class = ::Thread

        def self.backing_thread_class
          @backing_thread_class
        end

        def self.backing_thread_class=(clazz)
          @backing_thread_class = clazz
        end
      end
    end
  end
end
