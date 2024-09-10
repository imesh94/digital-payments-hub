import digitalpaymentshub/digital.payments.hub.paynet;

public isolated function switchToOutboundDriver(anydata iso20022Msg, string destination) returns anydata|error? {

    if (destination == "paynet") {
        
        return paynet:outbound(iso20022Msg);
    }
}