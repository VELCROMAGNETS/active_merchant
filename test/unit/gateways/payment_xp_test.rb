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
    @gateway.expects(:commit).once.with(expected_credit_card_options.merge(expected_address_options).merge(
      CustomInfo1: "blah blah blah",
      TransactionAmount: "4.00",
      TransactionType: "CreditCardCharge",
    ), instance_of(Hash))

    @gateway.purchase(@amount, @credit_card, address: @address, CustomInfo1: "blah blah blah")
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

  def test_purchase_with_customer_id_request
    @gateway.expects(:commit).once.with({
      CustomInfo1: "blah blah blah",
      CustomerID: "tok_123",
      TransactionAmount: "4.00",
      TransactionType: "AddCustomerCCCharge",
    }, instance_of(Hash))

    @gateway.purchase(@amount, "tok_123", address: @address, CustomInfo1: "blah blah blah")
  end

  def test_purchase_with_customer_id_response_success
    @gateway.stubs(:ssl_post).returns(purchase_for_customer_response_success)
    response = @gateway.purchase(@amount, "customer_123")

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "10016210"}, response.params.slice('TransactionID'))
    assert_equal "10016210", response.authorization
  end

  def test_purchase_with_customer_id_response_failure
    @gateway.stubs(:ssl_post).returns(purchase_for_customer_response_failure)
    response = @gateway.purchase(@amount, "customer_123")

    assert_equal false, response.success?
    assert_equal "", response.message
    assert_equal({'StatusID' => "5"}, response.params.slice('StatusID'))
  end

  def test_refund_request
    @gateway.expects(:commit).once.with(
      {
        custom: "foo",
        TransactionAmount: "2.34",
        TransactionID: "transaction_x",
        TransactionType: "CreditCardCredit",
      }, authorization_param: "TransactionID"
    )

    @gateway.refund(@refund_amount, "transaction_x", custom: "foo")
  end

  def test_refund_response_success
    @gateway.stubs(:ssl_post).returns(refund_response_success)
    response = @gateway.refund(@refund_amount, "transaction_x")

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9715402"}, response.params.slice('TransactionID'))
    assert_equal "9715402", response.authorization
  end

  def test_refund_response_failure
    @gateway.stubs(:ssl_post).returns(refund_response_failure)
    response = @gateway.refund(@refund_amount, "transaction_x")

    assert_equal false, response.success?
    assert_equal "MAX VALUE EXCEEDED", response.message
    assert_equal({"StatusID"=>"19"}, response.params.slice('StatusID'))
  end

  def test_store_request
    @gateway.expects(:commit).once.with(expected_credit_card_for_customer_options.merge(expected_address_for_customer_options).merge(
      custom: "foo",
      CustomerID: "123",
      TransactionType: "AddCustomer",
    ), instance_of(Hash))

    @gateway.store(@credit_card, address: @address, custom: "foo", customer_id: "123")
  end

  def test_store_response_success
    @gateway.stubs(:ssl_post).returns(store_response_success)
    response = @gateway.store(@credit_card)

    assert_equal true, response.success?
    assert_equal "APPROVED", response.message
    assert_equal({ "StatusID"=>"1" }, response.params.slice('StatusID'))
    assert_equal "86b856a9-c875-4129-8f81-9470888f2f77", response.authorization
  end

  def test_store_response_failure
    @gateway.stubs(:ssl_post).returns(store_response_failure)
    response = @gateway.store(@credit_card)

    assert_equal false, response.success?
    assert_equal "Invalid Credit Card", response.message
    assert_equal({ "StatusID"=>"0" }, response.params.slice('StatusID'))
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

  def test_add_creditcard_with_string_expiration
    credit_card = @credit_card.dup
    credit_card.month = credit_card.month.to_s
    credit_card.year = credit_card.year.to_s

    post = {}
    @gateway.send(:add_creditcard, post, credit_card)

    expected_credit_card_options.each do |key, value|
      assert_equal value, post[key]
    end
  end

  def test_add_money
    post = {}
    @gateway.send(:add_money, post, 1234)

    assert_equal "12.34", post[:TransactionAmount]
  end

  def test_commit_request
    @gateway.expects(:ssl_post)
      .once
      .with("https://webservice.paymentxp.com/wh/TestMethod.aspx", 'MerchantID=id_x&MerchantKey=key_x&Option1=foo')
      .returns(purchase_response_success)
    @gateway.send(:commit, { Option1: "foo" }, authorization_param: "TransactionID", endpoint: "TestMethod")
  end

  def test_commit_response_success
    @gateway.stubs(:ssl_post).returns(purchase_response_success)
    response = @gateway.send(:commit, {}, authorization_param: "TransactionID")

    assert_equal true, response.success?
    assert_equal "9475529", response.authorization
    assert_equal "APPROVED", response.message
    assert_equal({'TransactionID' => "9475529"}, response.params.slice('TransactionID'))
    assert_equal "Y", response.avs_result['code']
    assert_equal "M", response.cvv_result['code']
  end

  def test_commit_response_failure
    @gateway.stubs(:ssl_post).returns(purchase_response_failure)
    response = @gateway.send(:commit, {})

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

  def expected_address_for_customer_options
    {
      Address: '1234 My Street, Apt 1',
      PhoneNumber: '5555555555',
      City: 'Ottawa',
      Country: 'CA',
      CustomerName: 'Jim Smith',
      State: 'ON',
      Zip: 'K1C2N6',
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

  def expected_credit_card_for_customer_options
    {
      CustomerName: "Longbob Longsen",
      CardNumber: "4242424242424242",
      CardExpirationDate: "0115",
    }
  end

  def purchase_for_customer_response_success
    "PostedDate=3/3/2014 10:55:35 AM&StatusID=0&TransactionID=10016210&ReferenceNumber=&TransactionAmount=4.00&AuthorizationCode=541085&ResponseCode=00&ResponseMessage=APPROVED&CVV2ResponseCode=M&CVV2ResponseMessage=CVV MATCH&AVSResponseCode=Y&AVSResponseMessage=ADDRESS AND ZIP MATCH&URLPostback=&Table14Data=&CardNumber=4242&CustomerName=Longbob Longsen&BillingNameFirst=&BillingNameLast=&BillingAddress=1234 My Street Apt 1&BillingCity=Ottawa&BillingState=ON&BillingZipCode=K1C2N6&BillingCountry=CA&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=86b856a9-c875-4129-8f81-9470888f2f77&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def purchase_for_customer_response_failure
    "PostedDate=3/3/2014 10:56:32 AM&StatusID=5&TransactionID=&ReferenceNumber=&TransactionAmount=0.00&AuthorizationCode=0&ResponseCode=505&ResponseMessage=&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&BillingAddress=&BillingCity=&BillingState=&BillingZipCode=&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def purchase_response_success
    "PostedDate=2/12/2014 2:56:29 PM&StatusID=0&TransactionID=9475529&ReferenceNumber=&TransactionAmount=12.99&AuthorizationCode=710685&ResponseCode=00&ResponseMessage=APPROVED&CVV2ResponseCode=M&CVV2ResponseMessage=CVV MATCH&AVSResponseCode=Y&AVSResponseMessage=ADDRESS AND ZIP MATCH&URLPostback=&Table14Data=&CardNumber=4242&CustomerName=&BillingNameFirst=Jim&BillingNameLast=Smith&BillingAddress=1234 My Street Apt 1&BillingCity=Ottawa&BillingState=ON&BillingZipCode=K1C2N6&BillingCountry=CA&BillingPhone=5555555555&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def purchase_response_failure
    "PostedDate=2/12/2014 2:57:19 PM&StatusID=5&TransactionID=&ReferenceNumber=&TransactionAmount=12.99&AuthorizationCode=0&ResponseCode=503&ResponseMessage=INVALID CARD NUMBER&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&BillingAddress=&BillingCity=&BillingState=&BillingZipCode=&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def refund_response_success
    "PostedDate=2/21/2014 1:17:00 PM&StatusID=0&TransactionID=9715402&ReferenceNumber=&TransactionAmount=2.34&AuthorizationCode=0&ResponseCode=00&ResponseMessage=APPROVED&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=4242&CustomerName=Brian Alexander&BillingNameFirst=&BillingNameLast=&BillingAddress=123 Test St&BillingCity=Moab&BillingState=UT&BillingZipCode=84532&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def refund_response_failure
    "PostedDate=2/21/2014 1:17:19 PM&StatusID=19&TransactionID=&ReferenceNumber=&TransactionAmount=0.00&AuthorizationCode=0&ResponseCode=611&ResponseMessage=MAX VALUE EXCEEDED&CVV2ResponseCode=&CVV2ResponseMessage=&AVSResponseCode=&AVSResponseMessage=&URLPostback=&Table14Data=&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&BillingAddress=&BillingCity=&BillingState=&BillingZipCode=&BillingCountry=&BillingPhone=&BillingFax=&BillingEmail=&CustomerID=&ProductDescription=&Action=&RedirectUrl=&ShippingAddress1=&ShippingAddress2=&ShippingCity=&ShippingState=&ShippingZipCode=&ShippingCountry=&CustomInfo1=&CustomInfo2=&CustomInfo3=&CustomInfo4=&CustomInfo5=&CustomInfo6=&CustomInfo7=&CustomInfo8=&CustomInfo9=&CustomInfo10=&CustomInfo11=&CustomInfo12=&CustomInfo13=&CustomInfo14=&CustomInfo15=&CustomInfo16=&CustomInfo17=&CustomInfo18=&CustomInfo19=&CustomInfo20=&"
  end

  def store_response_success
    "PostedDate=3/3/2014 10:25:14 AM&StatusID=1&Message=&Status=APPROVED&CardNumber=4242&CustomerName=Longbob Longsen&BillingNameFirst=&BillingNameLast=&Address=1234 My Street Apt 1&City=Ottawa&State=ON&Zip=K1C2N6&Country=CA&Phone=&Fax=&Email=&BankName=&AccountName=&RoutingNumber=&AccountNumber=****&CardExpirationDate=0915&BankAccountType=&AvailablePaymentTypes=C&CustomerID=86b856a9-c875-4129-8f81-9470888f2f77&ShippingAddress=&ShippingCity=&ShippingState=&ShippingZip=&ShippingCountry=&"
  end

  def store_response_failure
    "PostedDate=3/3/2014 10:26:40 AM&StatusID=0&Message=Invalid Credit Card&Status=DENIED&CardNumber=&CustomerName=&BillingNameFirst=&BillingNameLast=&Address=&City=&State=&Zip=&Country=&Phone=&Fax=&Email=&BankName=&AccountName=&RoutingNumber=&AccountNumber=&CardExpirationDate=&BankAccountType=&AvailablePaymentTypes=&CustomerID=&ShippingAddress=&ShippingCity=&ShippingState=&ShippingZip=&ShippingCountry=&"
  end

end
