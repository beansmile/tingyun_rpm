# encoding: utf-8
require 'json'

module TingYun
  module Support
    class QuantileP2

      def self.support?
        return false if !TingYun::Agent.config[:'nbs.quantile']
        quantile = TingYun::Agent.config[:'nbs.quantile']
        quantile = JSON.parse(quantile) rescue false unless quantile.is_a?(Array)
        return false if !quantile || quantile.empty? || (quantile.size > quantile.uniq.size) || quantile.any? { |i| i.to_i == 0 || !i.is_a?(Fixnum)}
        return true
      end



      attr_accessor :quartileList, :markers_y, :markers_x, :p2_n, :count
      def initialize(quartileList)
        @quartileList = quartileList.sort!
        @markers_y = Array.new(@quartileList.length * 2 + 3){0.0}
        @count = 0
        initMarkers
      end

      def initMarkers
        quartile_count = quartileList.length
        marker_count = quartile_count * 2 + 3
        @markers_x = Array.new(marker_count){0.0}
        @markers_x[0] = 0.0
        @p2_n = Array.new(markers_y.length){0}
        (0..quartile_count-1).each do |i|
          marker = quartileList[i]
          markers_x[i * 2 + 1] = (marker + markers_x[i * 2]) / 2
          markers_x[i * 2 + 2] = marker
        end
        markers_x[marker_count - 2] = (1 + quartileList[quartile_count - 1]) / 2
        markers_x[marker_count - 1] = 1.0
        (0..marker_count-1).each do |i|
          p2_n[i] = i
        end
      end

      def markers

        if (count < markers_y.length)
          result = Array.new(count){0.0}
          markers = Array.new(markers_y.length){0.0}
          pw_q_copy = markers_y.clone()
          pw_q_copy.sort!
          j = 0
          (pw_q_copy.length - count .. pw_q_copy.length - 1).each do |i|
            result[j] = pw_q_copy[i]
            j+=1
          end

          (0..pw_q_copy.length-1).each do |i|
            markers[i] = result[((count - 1) * i * 1.0 / (pw_q_copy.length - 1)).round]
          end
          return markers;
        end

        return markers_y;
      end

      def binarySearch(arr, key)
        low = 0
        high = arr.length-1

        while(low <=high) do
          mid = (low + high) >> 1
          midVal = arr[mid]
          if (midVal < key)
            low = mid + 1
          elsif(midVal > key)
            high = mid - 1
          else
            midBits = midVal.round 16
            keyBits = key.round 16
            if (midBits == keyBits)
              return mid
            elsif(midBits < keyBits)
              low = mid + 1
            else
              high = mid - 1
            end
          end
        end
        return -(low + 1)
      end

      def quadPred(d, i)
        qi = markers_y[i]
        qip1 = markers_y[i + 1]
        qim1 = markers_y[i - 1]
        ni = p2_n[i]
        nip1 = p2_n[i + 1]
        nim1 = p2_n[i - 1]

        a = (ni - nim1 + d) * (qip1 - qi) / (nip1 - ni)
        b = (nip1 - ni - d) * (qi - qim1) / (ni - nim1)
        return qi + (d * (a + b)) / (nip1 - nim1)
      end


      def linPred(d, i)
        qi = markers_y[i]
        qipd = markers_y[i + d]
        ni = p2_n[i]
        nipd = p2_n[i + d]

        return qi + d * (qipd - qi) / (nipd - ni)
      end

      def add(v)

        return unless v.is_a?(Numeric)
        obsIdx = count
        @count += 1

        if (obsIdx < markers_y.length)
          markers_y[obsIdx] = v
          if (obsIdx == markers_y.length - 1)
            markers_y.sort!
          end
        else


          # k = markers_y.find_index {|i| i==v or i>v}
          #
          # if k ##in
          #   if v==markers_y[k] ##exist
          #     if k == 0##first
          #       markers_y[0] = v
          #       k = 1
          #     elsif k == markers_y.length-1 ##last
          #       k = markers_y.length - 1;
          #       markers_y[k] = v
          #     end
          #   end
          # else
          #   k = markers_y.length -1
          # end
          k = binarySearch markers_y, v

          if k< 0
            k = -(k + 1)
          end
          if k==0
            markers_y[0] = v
            k = 1
          elsif k == markers_y.length
            k = markers_y.length - 1
            markers_y[k] = v
          end

          (k..p2_n.length-1).each do |i|
            p2_n[i] += 1
          end

          (1..markers_y.length - 2).each do |i|

            n_ = markers_x[i] * obsIdx
            di = n_ - p2_n[i]
            if ((di-1.0 >=0.000001  && p2_n[i + 1] - p2_n[i] > 1) || ((di+1.0 <=0.000001  && p2_n[i - 1] - p2_n[i] < -1)))
              d = di < 0 ? -1 : 1
              qi_ = quadPred(d, i)
              if (qi_ < markers_y[i - 1] || qi_ > markers_y[i + 1])

                qi_ = linPred(d, i)
              end

              markers_y[i] = qi_

              p2_n[i] += d
            end
          end
        end
      end
    end
  end
end
#
# testdata4 =[0.0, 3009.0, 3046.0, 3070.0, 3102.0, 3119.0, 3139.0, 3150.0, 3163.0, 3179.0, 3228.0]
# testdata3 =[2,1,6,6,4,9,5,6,2,7,2,4,9,7,8,4,1,8,8,8,3,5,4,1,9,5,5,6,2,0,8,5,3,6,1,4,8,0,0,1,1,3,9,9,6,7,1,5,8,7,6,9,3,1,2,4,8,2,3,4,7,2,9,2,3,9,8,7,6,1,8,5,0,8,3,2,8,0,1,7,4,9,9,3,6,2,3,0,1,4,9,3,0,9,6,1,9,7,1,9,3,4,4,0,9,6,2,6,1,4,9,9,2,2,3,0,2,0,4,4,1,9,2,7,8,9,6,5,6,5,1,4,3,6,4,7,6,6,5,6,2,2,5,4,8,6,3,4,7,2,4,8,7,0,0,0,9,6,5,2,8,3,2,1,9,2,4,0,3,2,3,6,6,6,4,8,1,0,7,7,2,8,5,1,3,0,5,3,3,3,3,8,8,7,9,1,3,3,1,1,0,5,2,2,4,9,3,3,5,7,4,0,7,4,2,6,3,2,5,4,9,0,8,8,0,6,7,0,2,3,3,4,7,9,9,7,8,5,1,4,5,0,8,5,8,7,0,7,3,9,5,0,7,1,2,6,8,3,3,6,0,6,0,0,4,5,6,3,6,8,6,3,2,8,9,1,9,3,8,6,3,5,9,0,3,6,2,9,1,1,0,6,4,1,0,9,3,2,9,5,6,3,7,8,3,4,1,0,8,1,3,0,3,3,9,9,7,2,1,3,5,6,6,9,5,1,9,8,8,7,0,7,3,9,3,1,6,1,7,3,3,3,9,9,8,4,3,8,1,2,0,1,9,6,3,2,2,5,5,7,3,4,2,2,7,5,4,7,0,6,4,3,6,4,2,9,3,4,8,7,8,2,1,6,6,7,0,7,8,4,8,0,1,6,9,9,5,5,7,5,6,7,4,8,7,6,7,1,1,1,1,9,2,2,0,3,4,0,6,9,9,1,8,5,0,5,5,4,7,6,5,6,2,1,2,5,0,6,3,7,3,6,1,3,1,0,5,3,9,2,9,9,8,0,9,5,3,9,6,8,0,0,2,5,3,1,3,4,2,9,4,3,0,8,1,7,0,5,3,9,5,3,4,4,1,7,5,5,8,9,8,0,1,0,1,9,7,8,2,3,4,7,5,3,8,7,8,4,1,3,6,6,0,8,8,1,3,5,2,6,0,1,2,1,5,3,5,0,7,0,2,3,9,8,2,5,8,4,8,9,8,7,2,7,7,1,2,3,7,9,7,4,5,2,6,2,3,8,8,8,0,8,4,7,9,2,6,7,5,1,3,0,4,1,3,8,2,8,1,0,5,6,3,5,6,7,9,2,4,5,9,2,9,5,0,6,1,1,0,3,9,2,8,6,6,8,6,3,9,0,0,7,1,9,9,6,4,7,3,0,1,8,1,6,5,7,3,9,7,0,3,7,3,3,6,0,6,3,3,4,7,4,1,3,9,3,2,2,5,0,5,2,5,1,2,3,9,0,9,8,7,9,2,0,9,8,9,0,5,4,4,4,4,3,2,9,0,2,5,8,0,9,4,6,5,0,2,1,8,1,4,8,4,2,0,2,9,7,7,7,1,2,1,3,3,5,1,9,2,3,2,7,6,5,6,9,5,0,7,9,8,3,4,5,1,6,4,6,9,4,5,0,0,0,6,8,3,4,0,7,8,6,9,8,8,9,8,7,8,0,6,5,8,5,4,6,3,5,4,1,0,9,7,2,4,1,7,9,3,4,1,5,7,9,5,8,9,4,6,1,3,5,8,4,0,4,1,4,2,4,3,0,0,8,9,5,2,7,8,2,6,1,9,8,9,9,0,7,9,6,8,8,8,7,4,7,4,3,3,2,5,9,5,3,3,2,3,1,0,5,7,7,2,5,9,3,7,4,1,3,1,5,4,0,5,6,9,1,5,2,4,5,8,5,3,0,1,3,3,4,0,1,0,8,8,0,7,9,1,1,0,5,2,1,2,8,2,6,6,8,2,7,9,5,5,1,2,0,0,5,9,8,8,1,5,7,2,1,2,3,5,5,3,9,4,0,5,2,2,5,0,0,2,5,3,3,5,2,8,9,8,8,6,7,7,9,6,7,0,6,0,6,4,8,7,8,7,4,4,1,0,4,1,9,3,2,1,7,3,1,1,2,3,2,9,5,9,1,8,4,6,6,1,0,9,9,3,4,9,9,0,5,7,0,5,8,2,1,3,4,7,6,0,3,0,7,3,0,1,3,0,1,0,5,2,3,3,4,3,2]
# testdata2 =[3028.0, 2211.0]
# testdata1 =[3110,3770,3990,3990,3000,3880,3330,3440,3440,3000,3550,3440,3220,3330,3220,3110,3770,3110,3880,3330,3440,3440,3000,3110,3220,3440,3000,3550,3880,3990,3990,3550,3110,3330,3330,3000,3880,3660,3110,3990,3110,3990,3440,3330,3660,3660,3000,3220,3220,3330,3660,3990,3440,3220,3220,3440,3440,3880,3990,3550,3440,3110,3330,3440,3110,3770,3330,3220,3440,3440,3440,3220,3660,3000,3440,3550,3220,3220,3110,3660,3110,3880,3550,3770,3220,3440,3220,3110,3220,3220,3110,3880,3550,3770,3770,3550,3990,3220,3880,3660,3110,3550,3990,3110,3550,3880,3110,3770,3770,3110,3440,3770,3000,3110,3990,3110,3550,3770,3990,3000,3990,3110,3550,3880,3110,3880,3550,3220,3550,3550,3770,3990,3550,3220,3330,3990,3770,3770,3550,3770,3880,3660,3330,3990,3990,3000,3110,3440,3220,3000,3550,3770,3110,3550,3330,3990,3110,3330,3550,3440,3220,3550,3220,3330,3000,3660,3110,3770,3110,3660,3550,3440,3990,3330,3990,3550,3990,3550,3330,3770,3550,3550,3000,3440,3000,3330,3440,3110,3880,3110,3550,3660,3990,3220,3330,3330,3000,3660,3660,3220]
# testdatas =[testdata1.map(&:to_f),testdata2,testdata3.map(&:to_f),testdata4]
# quartileList =[1.0/7*2,1.0/7*3,1.0/7*4,1.0/7*5 ]
#
# qm=::TingYun::Support::QuantileP2.new(quartileList)
# # testdatas.each do |testdata|
# #   qp=::TingYun::Support::QuantileP2.new(quartileList)
# #   testdata.each do |da|
# #     qp.add(da)
# #     p qp.markers
# #     p "---------"
# #   end
# # end
# testdata4.each do |da|
#   qm.add(da.to_f)
# end
#
# p qm.markers
