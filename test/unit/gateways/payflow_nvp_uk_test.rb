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
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
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
    'RESULT=12&PNREF=E18P2B3E1843&RESPMSG=Declined'
  end
end
