# encoding: utf-8


module TingYun
  module Instrumentation
    module Support
      module ExternalHelper
        def create_tingyun_id(protocol)
          state = TingYun::Agent::TransactionState.tl_get
          externel_guid = tingyun_externel_guid
          state.extenel_req_id = externel_guid
          cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
              raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"
          state.add_current_node_params(:txId=>state.request_guid, :externalId=>state.extenel_req_id)
          "#{cross_app_id};c=1;x=#{state.request_guid};e=#{externel_guid};s=#{TingYun::Helper.time_to_millis(Time.now)};p=#{protocol}"
        end

        # generate a random 64 bit uuid
        def tingyun_externel_guid
          guid = ''
          16.times do
            guid << (0..15).map{|i| i.to_s(16)}[rand(16)]
          end
          guid
        end

        def self.metrics_for_message(product, ip_host, operation)
          if TingYun::Agent::Transaction.recording_web_transaction?
            metrics =["AllWeb", "All"]
          else
            metrics =["AllBackground", "All"]
          end

          metrics = metrics.map { |suffix| "Message #{product}/NULL/#{suffix}" }
          metrics.unshift "Message #{product}/#{ip_host}/#{operation}"
        end
      end
    end
  end
end


