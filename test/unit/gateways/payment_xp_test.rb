require 'test_helper'

class PaymentXpTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaymentXpGateway.new(merchant_id: 'id_x', merchant_key: 'key_x')

    @address = address()
    @credit_card = credit_card("4242424242424242", month: 1, year: 2015)
    @amount = 400
    # @refund_amount = 200
  end

  def test_purchase_request
    @gateway.expects(:commit).once.with("WebHost", expected_address_options.merge(expected_credit_card_options).merge(
      CustomInfo1: "blah blah blah",
      TransactionAmount: "4.00",
    ))

    @gateway.purchase(@amount, @credit_card, address: @address, CustomInfo1: "blah blah blah")
  end

  def test_purchase_request_with_token
    # FIXME with token
  end

  def test_purchase_response_success
    # FIXME response.success?
    # FIXME response.message
    # FIXME response.params
    # FIXME response.authorization
  end

  def test_purchase_response_failure
    # FIXME response.success?
    # FIXME response.message
    # FIXME response.params
  end

  def test_store_request
    # FIXME with credit card
  end

  def test_store_response_success
    # FIXME response.success?
    # FIXME response.message
    # FIXME response.params
    # FIXME response.authorization
  end

  def test_store_response_failure
    # FIXME response.success?
    # FIXME response.message
    # FIXME response.params
  end

  def test_add_address
    post = {}
    @gateway.send(:add_address, post, address: @address)

    expected_address_options.each do |key, value|
      assert_equal value, post[key]
    end
  end

  def test_add_creditcard
    post = {}
    @gateway.send(:add_creditcard, post, @credit_card)

    expected_credit_card_options.each do |key, value|
      assert_equal value, post[key]
    end
  end

  def test_add_creditcard_with_token
    post = {}
    @gateway.send(:add_creditcard, post, "token_123")

    assert_equal "token_123", post[:Token]
  end

  def test_add_money
    post = {}
    @gateway.send(:add_money, post, 1234)

    assert_equal "12.34", post[:TransactionAmount]
  end

  def test_add_tokenizable_creditcard
    post = {}
    @gateway.send(:add_tokenizable_creditcard, post, @credit_card)

    expected_credit_card_options.except(:BillingFullName).each do |key, value|
      assert_equal value, post[key]
    end
  end

  def test_commit_request
    @gateway.expects(:ssl_post)
      .once
      .with("https://webservice.paymentxp.com/wh/TestMethod.aspx", 'MerchantID=id_x&MerchantKey=key_x&Option1=foo')
      .returns(purchase_response_success)
    @gateway.send(:commit, "TestMethod", Option1: "foo")
  end

  def test_commit_response_success
    @gateway.stubs(:ssl_post).returns(purchase_response_success)
    response = @gateway.send(:commit, "TestMethod", {})

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9475529"}, response.params.slice('TransactionID'))
    assert_equal "Y", response.avs_result['code']
    assert_equal "M", response.cvv_result['code']
  end

  def test_commit_response_failure
    @gateway.stubs(:ssl_post).returns(purchase_response_failure)
    response = @gateway.send(:commit, "TestMethod", {})

    assert_equal false, response.success?
    assert_equal "INVALID CARD NUMBER", response.message
    assert_equal({'PostedDate' => "2/12/2014 2:57:19 PM"}, response.params.slice('PostedDate'))
  end

  private

  def expected_address_options
    {
      BillingAddress: '1234 My Street, Apt 1',
      PhoneNumber: '5555555555',
      BillingCity: 'Ottawa',
      BillingCountry: 'CA',
      BillingFullName: 'Jim Smith',
      BillingState: 'ON',
      BillingZipCode: 'K1C2N6',
    }
  end

  def expected_credit_card_options
    {
      BillingFullName: "Longbob Longsen",
      CardNumber: "4242424242424242",
      CVV2: "123",
      ExpirationDateMMYY: "0115",
    }
  end

  def purchase_response_success
    "PostedDate=2/12/2014 2:56:29 PM&StatusID=0&TransactionID=9475529&ReferenceNumber=&TransactionAmount=12.99&AuthorizationCode=710685&ResponseCode=00&ResponseMessage=APPROVED&CVV2ResponseCode=M&CVV2ResponseMessage=CVV MATCH&AVSResponseCode=Y&AVSResponseMessage=ADDRESS AND ZIP MATCH&URLPostback=&Table14Data=&CardNumber=4242&CustomerName=&BillingNameFirst=Jim&BillingNameLast=Smith&BillingAddress=1234 My Street Apt 1&BillingCity=Ottawa&BillingState=ON&BillingZipCode=K1C2N6&BillingCountry=CA&BillingPhone=5555555555&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def purchase_response_failure
    "PostedDate=2/12/2014 2:57:19 PM&StatusID=5&TransactionID=&ReferenceNumber=&TransactionAmount=12.99&AuthorizationCode=0&ResponseCode=503&ResponseMessage=INVALID CARD NUMBER&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&BillingAddress=&BillingCity=&BillingState=&BillingZipCode=&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

end
