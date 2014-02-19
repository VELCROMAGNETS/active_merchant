require 'test_helper'

class PaymentXpTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaymentXpGateway.new(merchant_id: 'id_x', merchant_key: 'key_x')

    @address = address()
    @credit_card = credit_card("4242424242424242", month: 1, year: 2015)
    @amount = 400
    @refund_amount = 234
  end

  def test_purchase_request
    @gateway.expects(:commit).once.with("WebHost", "TransactionID", expected_address_options.merge(expected_credit_card_options).merge(
      CustomInfo1: "blah blah blah",
      TransactionAmount: "4.00",
      TransactionType: "CreditCardCharge",
    ))

    @gateway.purchase(@amount, @credit_card, address: @address, CustomInfo1: "blah blah blah")
  end

  def test_purchase_request_with_token
    @gateway.expects(:commit).once.with("WebHost", "TransactionID", expected_address_options.merge(
      CustomInfo1: "blah blah blah",
      Token: "tok_123",
      TransactionAmount: "4.00",
      TransactionType: "CreditCardCharge",
    ))

    @gateway.purchase(@amount, "tok_123", address: @address, CustomInfo1: "blah blah blah")
  end

  def test_purchase_response_success
    @gateway.stubs(:ssl_post).returns(purchase_response_success)
    response = @gateway.purchase(@amount, @credit_card)

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9475529"}, response.params.slice('TransactionID'))
    assert_equal "9475529", response.authorization
  end

  def test_purchase_response_failure
    @gateway.stubs(:ssl_post).returns(purchase_response_failure)
    response = @gateway.purchase(@amount, @credit_card)

    assert_equal false, response.success?
    assert_equal "INVALID CARD NUMBER", response.message
    assert_equal({"StatusID"=>"5"}, response.params.slice('StatusID'))
  end

  def test_refund_request
    @gateway.expects(:commit).once.with("WebHost", "TransactionID",
      custom: "foo",
      TransactionAmount: "2.34",
      TransactionID: "transaction_x",
      TransactionType: "CreditCardAdjust",
    )

    @gateway.refund(@refund_amount, "transaction_x", custom: "foo")
  end

  def test_refund_response_success
    @gateway.stubs(:ssl_post).returns(refund_response_success)
    response = @gateway.refund(@refund_amount, "transaction_x")

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9652069"}, response.params.slice('TransactionID'))
    assert_equal "9652069", response.authorization
  end

  def test_refund_response_failure
    @gateway.stubs(:ssl_post).returns(refund_response_failure)
    response = @gateway.refund(@refund_amount, "transaction_x")

    assert_equal false, response.success?
    assert_equal "MAX VALUE EXCEEDED", response.message
    assert_equal({"StatusID"=>"19"}, response.params.slice('StatusID'))
  end

  def test_store_request
    @gateway.expects(:commit).once.with("GetToken", "Token", expected_credit_card_options.except(:BillingFullName).merge(custom: "foo"))

    @gateway.store(@credit_card, custom: "foo")
  end

  def test_store_response_success
    @gateway.stubs(:ssl_post).returns(store_response_success)
    response = @gateway.store(@credit_card)

    assert_equal true, response.success?
    assert_equal "Success", response.message
    assert_equal({"Token"=>"32d56fd7-c9e4-4709-b6c8-e4fda3701830", "StatusID"=>"0", "Message"=>"Success"}, response.params)
    assert_equal "32d56fd7-c9e4-4709-b6c8-e4fda3701830", response.authorization
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
    @gateway.send(:commit, "TestMethod", "TransactionID", Option1: "foo")
  end

  def test_commit_response_success
    @gateway.stubs(:ssl_post).returns(purchase_response_success)
    response = @gateway.send(:commit, "TransactionID", "TestMethod", {})

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9475529"}, response.params.slice('TransactionID'))
    assert_equal "Y", response.avs_result['code']
    assert_equal "M", response.cvv_result['code']
  end

  def test_commit_response_failure
    @gateway.stubs(:ssl_post).returns(purchase_response_failure)
    response = @gateway.send(:commit, "TransactionID", "TestMethod", {})

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

  def refund_response_success
    "PostedDate=2/19/2014 2:13:17 PM&StatusID=0&TransactionID=9652069&ReferenceNumber=&TransactionAmount=2.00&AuthorizationCode=0&ResponseCode=&ResponseMessage=APPROVED&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=4242&CustomerName=Longbob Longsen&BillingNameFirst=&BillingNameLast=&BillingAddress=1234 My Street Apt 1&BillingCity=Ottawa&BillingState=ON&BillingZipCode=K1C2N6&BillingCountry=CA&BillingPhone=5555555555&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def refund_response_failure
    "PostedDate=2/19/2014 2:15:00 PM&StatusID=19&TransactionID=&ReferenceNumber=&TransactionAmount=0.00&AuthorizationCode=0&ResponseCode=611&ResponseMessage=MAX VALUE EXCEEDED&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&BillingAddress=&BillingCity=&BillingState=&BillingZipCode=&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def store_response_success
    "Token=32d56fd7-c9e4-4709-b6c8-e4fda3701830&StatusID=0&Message=Success"
  end

end
