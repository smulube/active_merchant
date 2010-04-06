require 'test_helper'

class PayflowNvpUkTest < Test::Unit::TestCase
  def setup
    @gateway = PayflowNvpUkGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal 'E78P1FF791C2', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
  
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_add_creditcard
    result = {}

    @gateway.send(:add_creditcard, result, @credit_card)
    assert_equal "123", result[:cvv2]
    assert_equal "Longbob", result[:firstname]
    assert_equal "Longsen", result[:lastname]
    assert_equal "0911", result[:expdate]
  end

  def test_add_address
    result = {}
    
    @gateway.send(:add_address, result, { :address1 => '164 Waverley Street', :city => "Coldingham", :country => 'GB', :state => 'Essex', :zip => "NW12 8JB"} )
    assert_equal ["street", "city", "country", "state", "zip"].sort, result.stringify_keys.keys.sort
    assert_equal 'Essex', result["state"]
    assert_equal '164 Waverley Street', result["street"]
    assert_equal 'Coldingham', result["city"]
    assert_equal 'NW12 8JB', result["zip"]
    assert_equal 'GB', result["country"]
  end

  def test_add_shipping_address
    result = {}

    @gateway.send(:add_address, result, { :address1 => '164 Waverley Street', :city => "Coldingham", :country => 'GB', :state => 'Essex', :zip => "NW12 8JB"}, "shipto" )
    assert_equal ["shiptostreet", "shiptocity", "shiptocountry", "shiptostate", "shiptozip"].sort, result.stringify_keys.keys.sort
    assert_equal 'Essex', result["shiptostate"]
    assert_equal '164 Waverley Street', result["shiptostreet"]
    assert_equal 'Coldingham', result["shiptocity"]
    assert_equal 'NW12 8JB', result["shiptozip"]
    assert_equal 'GB', result["shiptocountry"]
  end

  def test_add_customer_data
    result = {}

    @gateway.send(:add_customer_data, result, { :ip => "2.3.4.5", :email => "john@jones.com", :customer => "johnjones" })
    assert_equal [:custref, :custip, :email].collect { |k| k.to_s }.sort, result.stringify_keys.keys.sort
    assert_equal "2.3.4.5", result[:custip]
    assert_equal "john@jones.com", result[:email]
    assert_equal "johnjones", result[:custref]
  end

  def test_add_order_id
    result = {}

    @gateway.send(:add_invoice, result, { :order_id => "12385" })
    assert_equal "12385", result[:invnum]
  end

  def test_custref_constrained_to_max_length
    result = {}

    @gateway.send(:add_customer_data, result, { :customer => "TheRightHonourableGeoff" })
    assert_equal "TheRightHono", result[:custref]
  end

  def test_add_currency_when_not_supplied
    result = {}

    @gateway.send(:add_currency, result, 1200, {})

    assert_equal "GBP", result[:currency]
  end

  def test_add_currency_when_supplied
    result = {}

    @gateway.send(:add_currency, result, 1200, { :currency => "USD" })

    assert_equal "USD", result[:currency]
  end

  def test_add_recurring_info
    result = {}

    time = 1.week.from_now

    @gateway.send(:add_recurring_info, result, @credit_card, @options.merge({ :starting_at => time, :payments => 12, :periodicity => :monthly }))
    assert_equal "Longbob Longsen", result[:profilename]
    assert_equal "A", result[:action]
    assert_equal "MONT", result[:payperiod]
    assert_equal 12, result[:term]
    assert_equal time.strftime("%m%d%Y"), result[:start]
  end

  def test_supported_countries
    assert_equal ['GB'], PayflowNvpUkGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :solo, :switch], PayflowNvpUkGateway.supported_cardtypes
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end
  
  def test_partial_avs_match
    #@gateway.expects(:ssl_post).returns(successful_duplicate_response)
    #
    #response = @gateway.purchase(@amount, @credit_card, @options)
    #assert_equal 'X', response.avs_result['code']
    #assert_equal 'Y', response.avs_result['street_match']
    #assert_equal 'N', response.avs_result['postal_match']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.cvv_result['code']
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    'RESULT=0&PNREF=E78P1FF791C2&RESPMSG=Approved&AUTHCODE=111111&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&PPREF=EYHMAP72DIEARC7JY&CORRELATIONID=2c9706997458s&IAVS=Y'
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    'RESULT=12&PNREF=E19P2B7C2B37&RESPMSG=Declined: 10417-General decline&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&IAVS=N'
  end

  def successful_authorization_response
    'RESULT=0&PNREF=E19P2B7CB478&RESPMSG=Approved&AUTHCODE=111111&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&PPREF=INPVKTX9GZDSSPOC4&CORRELATIONID=2c9706997458s&IAVS=N'
  end

  def successful_capture_response
    'RESULT=0&PNREF=E19P2B7CB4F6&RESPMSG=Approved&PPREF=B4BPVUEZYHPD5969O&CORRELATIONID=6c5704997466g'
  end

  def successful_recurring_response
    'RESULT=0&RESPMSG=Approved&RPREF=R79F2A3390CD&PROFILEID=I-00000000123456789&CORRELATIONID=2c9706997457r'
  end

  def successful_recurring_inquiry_response
    'RESULT=0&PNREF=E18P2B7CB1F1&RESPMSG=Approved&AUTHCODE=111111&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&PPREF=ZRKTDWXI5ORK2398T&CORRELATIONID=2c9706997458s&IAVS=N'
  end

  def successful_duplicate_response
  end

  def failed_recurring_response
  end
end
