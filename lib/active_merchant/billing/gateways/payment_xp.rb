module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentXpGateway < Gateway
      # FIXME class attributes

      BASE_URL = "https://webservice.paymentxp.com/wh/".freeze

      def initialize(options = {})
        @merchant_id = options[:merchant_id]
        @merchant_key = options[:merchant_key]
        super
      end

      def authorize
        # FIXME
      end

      def capture
        # FIXME
      end

      def purchase(money, card, options = {})
        post = {}
        add_address post, options
        add_creditcard post, card
        add_money post, money
        add_options post, options
        post[:TransactionType] = "CreditCardCharge"

        commit("WebHost", "TransactionID", post)
      end

      def refund(money, transaction_id, options = {})
        post = {}
        add_money post, money
        add_options post, options
        post[:TransactionID] = transaction_id
        post[:TransactionType] = "CreditCardCredit"

        commit("WebHost", "TransactionID", post)
      end

      def store(card, options = {})
        post = {}
        add_tokenizable_creditcard(post, card)
        add_options(post, options)

        commit("GetToken", "Token", post)
      end

      def void
        # FIXME
      end

      private

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:BillingAddress] = [address[:address1], address[:address2]].reject(&:blank?).join(", ") if address[:address1]
          post[:PhoneNumber] = address[:phone].gsub(/[^\d]/, "") if address[:phone]
          {
            city: :BillingCity,
            country: :BillingCountry,
            name: :BillingFullName,
            state: :BillingState,
            zip: :BillingZipCode,
          }.each do |key, gateway_key|
            post[gateway_key] = address[key] if address[key]
          end
        end
      end

      def add_creditcard(post, card)
        if card.respond_to?(:number)
          add_tokenizable_creditcard(post, card)

          post[:BillingFullName] = card.name if card.name
        else
          post[:Token] = card
        end
      end

      def add_money(post, money)
        post[:TransactionAmount] = "%.2f" % (money / 100.0)
      end

      def add_options(post, options)
        post.merge! options.except(:address, :billing_address)
      end

      def add_tokenizable_creditcard(post, card)
        post[:CardNumber] = card.number if card.number
        post[:CVV2] = card.verification_value if card.verification_value
        post[:ExpirationDateMMYY] = "%02d%02d" % [card.month, card.year - 2000] if card.year && card.month
      end

      def commit(endpoint, authorization_key, params)
        params = params.merge(MerchantID: @merchant_id, MerchantKey: @merchant_key).to_query

        raw_response = ssl_post("#{BASE_URL}#{endpoint}.aspx", params)
        response = Hash[CGI.parse(raw_response).map { |k, v| [k, v.first] }]

        Response.new(
          response['StatusID'] == "0",
          response['ResponseMessage'] || response['Message'],
          response,
          authorization: response[authorization_key],
          avs_result: { code: response['AVSResponseCode'] },
          cvv_result: response['CVV2ResponseCode'],
        )
      end
    end
  end
end
