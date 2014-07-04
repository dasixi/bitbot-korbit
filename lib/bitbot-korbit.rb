require 'bitbot'
require 'korbit'

module BitBot
  module Korbit

    def ticker
      map  = {volume: :vol}
      resp = client.get '/v1/ticker/detailed'
      check_response(resp)

      Ticker.new rekey(resp, map).merge(original: resp, agent: self)
    end

    def offers
      resp = client.get '/v1/orderbook'
      check_response(resp)

      asks = resp['asks'].collect do |offer|
        Offer.new price: offer[0], amount: offer[1], original: offer, agent: self
      end
      bids = resp['bids'].collect do |offer|
        Offer.new price: offer[0], amount: offer[1], original: offer, agent: self
      end

      {asks: asks, bids: bids}
    end

    def asks
      offers[:asks]
    end

    def bids
      offers[:bids]
    end

    def buy(options)
      resp = client.post '/v1/user/orders/buy', type: 'limit', price: options[:price].to_i, coin_amount: options[:amount]
      check_response(resp)
      Order.new(order_id: resp['orderId'], side: 'buy', type: 'limit', price: options[:price], amount: options[:amount], status: 'open')
    end

    def sell(options)
      resp = client.post '/v1/user/orders/sell', type: 'limit', price: options[:price].to_i, coin_amount: options[:amount]
      check_response(resp)
      Order.new(order_id: resp['orderId'], side: 'sell', type: 'limit', price: options[:price], amount: options[:amount], status: 'open')
    end

    def cancel(order_id)
      resp = client.post('/v1/user/orders/cancel', id: order_id).first
      check_response(resp)
      Order.new order_id: order_id, status: 'cancelled'
    end

    def sync(order)
      order_id = order.is_a?(BitBot::Order) ? order.order_id : order.to_i
      open_order = orders.find{|oo| oo.order_id == order_id }
      filled = filled_of_order(order_id)

      if open_order.nil?
        if filled == 0
          { status: 'cancelled' }
        else
          attrs = { status: 'closed' }
          if order.is_a?(BitBot::Order)
            attrs.merge!(remaining: order.amount - filled)
          end
          attrs
        end
      else
        order
      end
    end

    def orders
      resp = client.get '/v1/user/orders/open'
      check_response(resp) unless resp.is_a? Array

      resp.collect do |hash|
        build_order(hash)
      end
    end

    def account
      resp = client.get '/v1/user/wallet'
      check_response(resp)
      build_account(resp)
    end

    def currency
      'KRW'
    end

    def client
      @client ||= ::Korbit::Client.new(
        client_id: @key,
        client_secret: @secret,
        username: @options[:username],
        password: @options[:password],
      )
    end


    private

    def check_response(response)
      status = response['status']
      return true if status.nil? or status == 'success'

      case status
      when 'not_enough_krw' then raise InsufficientMoneyError, status
      when 'not_enough_btc' then raise InsufficientCoinError, status
      when 'not_found' then raise OrderNotFoundError, status
      when 'already_filled' then raise UnknowError, status
      when 'partially_filled' then raise UnknowError, status
      when 'already_canceled' then raise CanceledError, status
      else raise Error, status
      end
    end

    def filled_of_order(order_id)
      txs = client.get '/v1/user/transactions', category: 'fills', order_id: order_id

      txs.empty? ? 0 : txs.sum{|tx| tx['fillsDetail']['amount']['value'].to_f }
    end

    def build_order(hash)
      attr = {
        order_id: hash['id'],
        side: hash['type'] == 'ask' ? 'sell' : 'buy',
        price: hash['price']['value'],
        amount: hash['total']['value'],
        remaining: hash['open']['value'],
        timestamp: hash['timestamp'].to_f / 1000,
        status: 'open',
        type: 'limit'
      }

      Order.new attr.merge(original: hash, agent: self)
    end

    def build_account(resp)
      account = Account.new original: resp, agent: self
      account.balances = build_balances(resp)
      account
    end

    def build_balances(resp)
      balances = []

      currencies = resp['balance'].reduce([]){|memo, hash| memo << hash['currency']; memo }
      currencies.each do |currency|
        amount = resp['available'].find{|hash| hash['currency'] == currency }['value'].to_f
        total = resp['balance'].find{|hash| hash['currency'] == currency }['value'].to_f

        balances << Balance.new(currency: currency.upcase, amount: amount, locked: (total - amount).round(12), original: resp, agent: self)
      end

      balances
    end

  end
end

BitBot.define :korbit, BitBot::Korbit
