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
      self.money_format = :dollars
      self.timeout = 30

      TRANSACTIONS = { 
        :purchase       => "S",
        :authorization  => "A",
        :capture        => "D",
        :void           => "V",
        :credit         => "C",
        :recurring      => "R"
      }

      PERIODS = {
        :daily => "EDAY",
        :weekly => "WEEK",
        :biweekly => "BIWK",
        :semimonthly => "SMMO",
        :quadweekly => "FRWK",
        :monthly => "MONT",
        :quarterly => "QTER",
        :semiyearly => "SMYR",
        :yearly => "YEAR"
      }

      RECURRING_ACTIONS = {
        :create => "A",
        :modify => "M",
        :deactivate => "C",
        :reactivate => "R",
        :inquiry => "I"
      }

      # Creates a new PayflowNvpUkGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Parameters
      #
      # * <tt>options</tt>
      #   * <tt>:login</tt> - Your Payflow login
      #   * <tt>:password</tt> - Your Payflow password
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        @options[:partner] = partner if @options[:partner].blank?
        super
      end


      # Is the gateway in test mode?
      def test?
        @options[:test] || super
      end

      # Performs an authorization transaction. This is required due to Visa and
      # Mastercard restrictions, in that a customer's card cannot be charged
      # until the goods have been dispatched. An authorization allows an amout
      # to be reserved on a customer's card, bringing down the available
      # balance or credit, but they are not actually charged until a subsequent
      # capture step actually captures the funds.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be charged as an integer value in cents.
      # * <tt>creditcard</tt> - The CreditCard object to be used as a funding source for the transaction.
      # * <tt>options</tt> - A hash of optional parameters
      #   * <tt>:order_id</tt> - A unique reference for this order (maximum of 127 characters).
      #   * <tt>:email</tt> - The customer's email address
      #   * <tt>:customer</tt> - A unique reference for the customer (maximum of 12 characters).
      #   * <tt>:ip</tt> - The customer's IP address
      #   * <tt>:currency</tt> - The currency of the transaction. If present must be one of { AUD, CAD, EUR, JPY, GBP or USD }. If omitted the default currency is used.
      #   * <tt>:billing_address</tt> - The customer's billing address as a hash of address information.
      #     * <tt>:address1</tt> - The billing address street
      #     * <tt>:city</tt> - The billing address city
      #     * <tt>:state</tt> - The billing address state
      #     * <tt>:country</tt> - The 2 digit ISO billing address country code
      #     * <tt>:zip</tt> - The billing address zip code
      #   * <tt>:shipping_address</tt> - The customer's shipping address as a hash of address information.
      #     * <tt>:address1</tt> - The shipping address street
      #     * <tt>:city</tt> - The shipping address city
      #     * <tt>:state</tt> - The shipping address state code
      #     * <tt>:country</tt> - The 2 digit ISO shipping address country code
      #     * <tt>:zip</tt> - The shipping address zip code
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_currency(post, money, options)
        add_address(post, options[:billing_address] || options[:address])
        add_address(post, options[:shipping_address], "shipto")
        add_customer_data(post, options)
        
        commit(TRANSACTIONS[:authorize], money, post)
      end
      
      # A purchase transaction authorizes and captures in a single hit. We can only
      # do this for transactions where you provide immediate fulfillment of products or services.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be charged as an integer value in cents.
      # * <tt>creditcard</tt> - The CreditCard object to be used as a funding source for the transaction.
      # * <tt>options</tt> - A hash of optional parameters
      #   * <tt>:order_id</tt> - A unique reference for this order (maximum of 127 characters).
      #   * <tt>:email</tt> - The customer's email address
      #   * <tt>:customer</tt> - A unique reference for the customer (maximum of 12 characters).
      #   * <tt>:ip</tt> - The customer's IP address
      #   * <tt>:currency</tt> - The currency of the transaction. If present must be one of { AUD, CAD, EUR, JPY, GBP or USD }. If ommitted the default currency is used.
      #   * <tt>:billing_address</tt> - The customer's billing address as a hash of address information.
      #     * <tt>:address1</tt> - The billing address street
      #     * <tt>:city</tt> - The billing address city
      #     * <tt>:state</tt> - The billing address state
      #     * <tt>:country</tt> - The 2 digit ISO billing address country code
      #     * <tt>:zip</tt> - The billing address zip code
      #   * <tt>:shipping_address</tt> - The customer's shipping address as a hash of address information.
      #     * <tt>:address1</tt> - The shipping address street
      #     * <tt>:city</tt> - The shipping address city
      #     * <tt>:state</tt> - The shipping address state code
      #     * <tt>:country</tt> - The 2 digit ISO shipping address country code
      #     * <tt>:zip</tt> - The shipping address zip code
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_currency(post, money, options)
        add_address(post, options[:billing_address] || options[:address])   
        add_address(post, options[:shipping_address], "shipto")
        add_customer_data(post, options)
             
        commit(TRANSACTIONS[:purchase], money, post)
      end                       
    
      # Captures authorized funds.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount to be authorized as an integer value in cents. Payflow does support changing the captured amount, so whatever is passed here will be captured.
      # * <tt>authorization</tt> - The authorization reference string returned by the original transaction's Response#authorization.
      # * <tt>options</tt> - not currently used.
      def capture(money, authorization, options = {})
        post = {}
        post[:origid] = authorization

        commit(TRANSACTIONS[:capture], money, post)
      end

      # Voids an authorization or delayed capture
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization reference string returned by the original transaction's Response#authorization.
      # * <tt>options</tt> - Not currently used.
      def void(authorization, options = {})
        post = {}
        post[:origid] = authorization

        commit(TRANSACTIONS[:void], nil, post)
      end

      # Process a refund to a customer.
      #
      # ==== Parameters
      # * <tt>money</tt> - The amount to be credited as an integer value in cents.
      # * <tt>authorization_or_card</tt> - The CreditCard you want to refund to OR the PayPal PNRef of a previous transaction. It depends on the settings in your PayPal account as to whether non referenced credits are permitted. The default is that they are not.
      # * <tt>options</tt> - not currently used
      def credit(money, authorization_or_card, options = {})
        post = {}
        
        if authorization_or_card.is_a?(String)
          # perform a referenced credit
          post[:origid] = authorization
        else
          # perform an unreferenced credit
          add_creditcard(post, creditcard)        
        end
        
        commit(TRANSACTIONS[:credit], money, post)
      end

      # Create or modify a recurring profile.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> - The amount that the recurring profile is to be set up for as an integer value in cents.
      # * <tt>creditcard</tt> - The CreditCard object to be used as a funding source for the recurring profile.
      # * <tt>options</tt> - A hash of parameters (some optional).
      #   * <tt>:profile_id</tt> - If present then we are modifying an existing profile, and this :profile_id identifies the profile we want to amend. If not present then we are creating a new recurring payments profile.
      #   * <tt>:starting_at</tt> - Takes a Date, Time or string in MMDDYYYY format. The date must be in the future.
      #   * <tt>:name</tt> - The name of the customer to be billed. If omitted the name from the creditcard is used.
      #   * <tt>:periodicity</tt> - The frequency that the recurring payments will occur at. Can be one of: [:daily, :weekly, :biweekly (every 2 weeks), :semimonthly (twice every month), :quadweekly (once every 4 weeks), :monthly (every month on the same date as the first payment), :quarterly (every 3 months on the same date as the first payment), :semiyearly (every 6 months on the same date as the first payment), :yearly.
      #   * <tt>:payments</tt> - Integer value describing the number of payments to be made.
      #   * <tt>:comment<tt> - Optional description of the goods or service being purchased
      #   * <tt>:max_failed_payments</tt> - The number of payments that are allowed to fail before PayPal suspends the profile. Defaults to 0 which means PayPal will never suspend the profile until the term is completed. PayPal will keep attempting to process failed payments.
      #   * <tt>:currency</tt> - The currency of the transaction. If present must be one of { AUD, CAD, EUR, JPY, GBP or USD }. If omitted the default currency is used.
      def recurring(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_currency(post, money, options)
        add_address(post, options[:billing_address] || options[:address])
        add_address(post, options[:shipping_address], "shipto")
        add_customer_data(post, options)
        add_recurring_info(post, creditcard, options)

        commit(TRANSACTIONS[:recurring], money, post)
      end

      # Inquire about the status of a previously created recurring profile.
      #
      # ==== Parameters
      #
      # * <tt>profile_id</tt>
      # * <tt>options</tt>
      def recurring_inquiry(profile_id, options = {})
        post = {}

        post[:action] = RECURRING_ACTIONS[:inquiry]
        post[:origprofileid] = profile_id.to_s

        commit(TRANSACTIONS[:recurring], nil, options)
      end

      # Cancel a recurring profile.
      #
      # ==== Parameters
      #
      # * <tt>profile_id</tt>
      def cancel_recurring(profile_id)
        post = {}

        post[:action] = RECURRING_ACTIONS[:deactivate]
        post[:origprofileid] = profile_id.to_s

        commit(TRANSACTIONS[:recurring], nil, nil)
      end
    
      private                       
      
      def add_customer_data(post, options)
        post[:email] = options[:email].to_s if options.has_key?(:email)
        post[:custref] = options[:customer].to_s.slice(0,12) if options[:customer]
        post[:custip] = options[:ip].to_s if options[:ip]
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
          post[prefix+"zip"]       = address[:zip].to_s.sub(/\s+/,'')
        end         
      end

      def add_invoice(post, options)
        post[:invnum] = (options[:invoice] || options[:order_id]).to_s.slice(0,127) if options.has_key?(:invoice) || options.has_key?(:order_id) 
      end
      
      def add_creditcard(post, creditcard)      
        post[:acct] = creditcard.number
        post[:cvv2] = creditcard.verification_value
        post[:expdate] = expdate(creditcard)
        post[:firstname] = creditcard.first_name
        post[:lastname]  = creditcard.last_name   
      end
      
      def add_currency(post, money, options)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_recurring_info(post, creditcard, options)
        post[:action] = options.has_key?(:profile_id) ? RECURRING_ACTIONS[:modify] : RECURRING_ACTIONS[:create]
        post[:start] = format_date(options[:starting_at])
        post[:term] = options[:payments] unless options[:payments].nil?
        post[:payperiod] = PERIODS[options[:periodicity]]
        post[:desc] = options[:comment] unless options[:comment].nil?
        post[:maxfailedpayments] = options[:max_failed_payments] unless options[:max_failed_payments].nil?
        post[:profilename] = (options[:name] || creditcard.name).to_s.slice(0,128)
      end

      def format_date(time)
        case time
          when Time, Date then time.strftime("%m%d%Y")
        else
          time.to_s
        end
      end

      def expdate(creditcard)
        year  = sprintf("%.04i", creditcard.year.to_i)
        month = sprintf("%.02i", creditcard.month.to_i)

        "#{month}#{year[-2..-1]}"
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
        post[:partner] = @options[:partner]
        post[:vendor] = @options[:login]
        post[:trxtype] = action if action
        post[:tender] = "C"
        post[:verbosity] = "MEDIUM"
        
        request = post.merge(parameters).map { |key, value| "#{key.to_s.upcase}=#{CGI.escape(value.to_s)}" }.join("&")
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
        parameters[:amt]  = amount(money) if money

        request = build_request(parameters, action)
        headers = build_headers(request.size)

    	  response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request, headers))

        Response.new(response["RESULT"] == "0", response["RESPMSG"], response, 
          :authorization => response["PNREF"],
          :test => test?,
          :cvv_result => response["PROCCVV2"],
          :avs_result => { :code => response["PROCAVS"], :postal_match => response["AVSZIP"], :street_match => response["AVSADDR"] }
        )
        
      end
    end
  end
end

