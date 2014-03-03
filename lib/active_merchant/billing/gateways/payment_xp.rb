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

      def purchase(money, card_or_customer_id, options = {})
        post = {}

        if card_or_customer_id.respond_to?(:number)
          add_creditcard post, card_or_customer_id
          add_address post, options
          post[:TransactionType] = "CreditCardCharge"
        else
          post[:CustomerID] = card_or_customer_id
          post[:TransactionType] = "AddCustomerCCCharge"
        end

        add_money post, money
        add_options post, options

        commit(post, authorization_param: "TransactionID")
      end

      def refund(money, transaction_id, options = {})
        post = {}
        add_money post, money
        add_options post, options
        post[:TransactionID] = transaction_id
        post[:TransactionType] = "CreditCardCredit"

        commit(post, authorization_param: "TransactionID")
      end

      def store(card, options = {})
        # GetToken method returns a token that expires in 15 minutes. AddCustomer must
        # be used to generate a persistent token.
        customer_id = options[:customer_id] || SecureRandom.uuid

        post = {}
        add_creditcard(post, card)
        add_address post, options
        convert_param_names_for_customer(post)
        add_options(post, options)

        post[:CustomerID] = customer_id
        post[:TransactionType] = "AddCustomer"

        # Most other API calls use a StatusID of "0" to indicate success. Customer calls use "1" to
        # indicate success and "0" to indicate failure. This inconsistency is undocumented.
        commit(post, authorization_param: "CustomerID", success_status: "1")
      end

      def unstore
        # FIXME
      end

      def update
        # FIXME
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
        post[:BillingFullName] = card.name if card.name
        post[:CardNumber] = card.number if card.number
        post[:CVV2] = card.verification_value if card.verification_value
        post[:ExpirationDateMMYY] = "%02d%02d" % [card.month.to_i, card.year.to_i - 2000] if card.year && card.month
      end

      def add_money(post, money)
        post[:TransactionAmount] = "%.2f" % (money / 100.0)
      end

      def add_options(post, options)
        post.merge! options.except(:address, :billing_address, :customer_id)
      end

      def convert_param_names_for_customer(post)
        # AddCustomer and UpdateCustomer require the same parameters as CreditCardAuthorization and
        # CreditCardCharge, but they have different names :(
        {
          CustomerName: :BillingFullName,
          CardExpirationDate: :ExpirationDateMMYY,
          Address: :BillingAddress,
          City: :BillingCity,
          Country: :BillingCountry,
          State: :BillingState,
          Zip: :BillingZipCode,
        }.each do |to, from|
          post[to] = post.delete(from) if post.key?(from)
        end

        post.delete(:CVV2)
      end

      def commit(params, options = {})
        endpoint = options[:endpoint] || "WebHost"
        success_status = options[:success_status] || "0"

        params = params.merge(MerchantID: @merchant_id, MerchantKey: @merchant_key).to_query

        raw_response = ssl_post("#{BASE_URL}#{endpoint}.aspx", params)
        response = Hash[CGI.parse(raw_response).map { |k, v| [k, v.first] }]

        Response.new(
          response['StatusID'] == success_status,
          %w[ResponseMessage Message Status].map { |k| response[k] }.reject(&:blank?).first || "",
          response,
          authorization: response[options[:authorization_param]],
          avs_result: { code: response['AVSResponseCode'] },
          cvv_result: response['CVV2ResponseCode'],
        )
      end
    end
  end
end
