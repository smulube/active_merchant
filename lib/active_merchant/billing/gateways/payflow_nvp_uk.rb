module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowNvpUkGateway < Gateway
      TEST_URL = 'https://pilot-payflowpro.paypal.com'
      LIVE_URL = 'https://payflowpro.paypal.com'
      
      self.class_inheritable_accessor :partner
      self.class_inheritable_accessor :timeout

      # Enable safe retry of failed connections
      # Payflow is safe to retry because retried transactions use the same
      # X-VPS-Request-ID header. If a transaction is detected as a duplicate
      # only the original transaction data will be used by Payflow, and the
      # subsequent Responses will have a :duplicate parameter set in the params
      # hash.
      self.retry_safe = true
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['GB']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :solo, :switch]
      
      # The homepage URL of the gateway
      self.homepage_url = 'https://www.paypal.com/uk/cgi-bin/webscr?cmd=_wp-pro-overview-outside'
      
      # The name of the gateway
      self.display_name = 'PayPal Website Payments Pro (UK) [NVP API]'
      
      self.default_currency = 'GBP'
      self.partner = 'PayPalUk'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        @options[:partner] = partner if @options[:partner].blank?
        super
      end

      def test?
        @options[:test] || super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, options[:billing_address] || options[:address])
        add_address(post, options[:shipping_address], "shipto")
        add_customer_data(post, options)
        
        commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, options)   
        add_customer_data(post, options)
             
        commit('S', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      # NOTE : If you pass in any of the ship-to address parameters such as SHIPTOCITY or
      # SHIPTOSTATE, you must pass in the complete set (that is, SHIPTOSTREET,
      # SHIPTOCITY, SHIPTOSTATE, SHIPTOCOUNTRY, and SHIPTOZIP).
      def add_address(post, address, prefix = '')      
        unless address.blank? or address.values.blank?
          post[prefix+"street"]    = address[:address1].to_s
          post[prefix+"city"]      = address[:city].to_s
          post[prefix+"state"]     = address[:state].blank?  ? 'n/a' : address[:state]
          post[prefix+"country"]   = address[:country].to_s
          post[prefix+"zip"]       = address[:zip].to_s       
        end         
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)      
      end
      
      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end
        
        results
      end     

      def build_request(parameters, action = nil)
        post = {}
        post[:user] = @options[:login]
        post[:pwd] = @options[:password]
        post[:trxtype] = action if action
        
        request = post.merge(parameters).map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def build_headers(content_length)
        {
          "Content-Type" => "text/namevalue",
          "Content-Length" => content_length.to_s,
      	  "X-VPS-Client-Timeout" => timeout.to_s,
      	  "X-VPS-VIT-Integration-Product" => "ActiveMerchant",
      	  "X-VPS-VIT-Runtime-Version" => RUBY_VERSION,
      	  "X-VPS-Request-ID" => Utils.generate_unique_id
    	  }
      end
      
      def commit(action, money, parameters)
        request = build_request(parameters, action)
        headers = build_headers(request.size)

        parameters[:amount]  = amount(money) if money
    	  response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request, headers))
        Response.new(response["RESULT"] == "0", response["RESPMSG"], response, 
          :authorization => response["PNREF"],
          :test => test?,
          :cvv_result => response["CVV2MATCH"],
          :avs_result => { :code => response["IAVS"] }
        )
        
      end
    end
  end
end

