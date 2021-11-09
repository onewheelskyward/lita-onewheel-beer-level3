require 'rest-client'
require 'lita-onewheel-beer-base'
require 'json'

module Lita
  module Handlers
    class OnewheelBeerLevel3 < OnewheelBeerBase
      route /^level3$/i,
            :taps_list,
            command: true,
            help: {'level3' => 'Display the current taps.'}

      route /^level3 ([\w ]+)$/i,
            :taps_deets,
            command: true,
            help: {'level3 4' => 'Display the tap 4 deets, including prices.'}

      route /^level3 ([<>=\w.\s]+)%$/i,
            :taps_by_abv,
            command: true,
            help: {'level3 >4%' => 'Display beers over 4% ABV.'}

      route /^level3 ([<>=\$\w.\s]+)$/i,
            :taps_by_price,
            command: true,
            help: {'level3 <$5' => 'Display beers under $5.'}

      route /^level3 (roulette|random)$/i,
            :taps_by_random,
            command: true,
            help: {'level3 roulette' => 'Can\'t decide?  Let me do it for you!'}

      route /^level3low$/i,
            :taps_by_remaining,
            command: true,
            help: {'level3low' => 'Show me the kegs at <10% remaining, or the lowest one available.'}

      route /^level3abvlow$/i,
            :taps_low_abv,
            command: true,
            help: {'level3abvlow' => 'Show me the lowest abv keg.'}

      route /^level3abvhigh$/i,
            :taps_high_abv,
            command: true,
            help: {'level3abvhigh' => 'Show me the highest abv keg.'}

      def taps_list(response)
        # wakka wakka
        beers = self.get_source
        reply = "Level3 taps: "
        beers.each do |tap, datum|
          reply += "#{tap}) "
          reply += get_tap_type_text(datum[:type])
          reply += datum[:brewery].to_s + ' '
          reply += (datum[:name].to_s.empty?)? '' : datum[:name].to_s + '  '
        end
        reply = reply.strip.sub /,\s*$/, ''

        Lita.logger.info "Replying with #{reply}"
        response.reply reply
      end

      def send_response(tap, datum, response)
        reply = "Level3 tap #{tap}) #{get_tap_type_text(datum[:type])}"
        reply += "#{datum[:brewery]} "
        reply += "#{datum[:name]} "
        reply += "- #{datum[:desc]}, "
        # reply += "Served in a #{datum[1]['glass']} glass.  "
        reply += "#{get_display_prices datum[:prices]}, "
        reply += "#{datum[:remaining]}"

        Lita.logger.info "send_response: Replying with #{reply}"

        response.reply reply
      end

      def get_display_prices(prices)
        price_array = []
        prices.each do |p|
          price_array.push "#{p[:size]} - $#{p[:cost]}"
        end
        price_array.join ' | '
      end

      def get_source
        # https://visualizeapi.com/api/level3
        # Lita.logger.debug "get_source started"
        # unless (response = redis.get('page_response'))
        #   Lita.logger.info 'No cached result found, fetching.'
        uri = 'https://jerrysv.xyz/api/beer/level?location=Level%203'
        Lita.logger.info "Getting uri"
        response = RestClient.get(uri)
          # redis.setex('page_response', 1800, response)
        # end
        parse_response response
      end

      # This is the worker bee- decoding the html into our "standard" document.
      # Future implementations could simply override this implementation-specific
      # code to help this grow more widely.
      def parse_response(response)
        Lita.logger.debug "parse_response started."
        gimme_what_you_got = {}
        resp = JSON.parse response
        resp['taps'].each do |beer_node|
          tap = beer_node[0]
          metadata = beer_node[1]
          # tap_name = metadata['name']
          # tap_type = tap_name.match(/(cask|nitro)/i).to_s

          # remaining = beer_node.attributes['title'].to_s

          brewery = metadata['brewery']
          beer_name = metadata['name']
          beer_desc = metadata['short_description']
          abv = metadata['abv']
          full_text_search = "#{tap.sub /\d+/, ''} #{brewery} #{beer_name} #{beer_desc.to_s.gsub /\d+\.*\d*%*/, ''}"
          # prices = get_prices(beer_node)

          gimme_what_you_got[tap] = {
              # type: tap_type,
              # remaining: remaining,
              brewery: brewery.to_s,
              name: beer_name.to_s,
              desc: beer_desc.to_s,
              abv: abv.to_f,
              # prices: prices,
              # price: prices[1][:cost],
              search: full_text_search
          }
        end
        gimme_what_you_got
      end

      Lita.register_handler(self)
    end
  end
end
