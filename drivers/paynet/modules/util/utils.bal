import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/random;
import ballerina/time;
import ballerinax/financial.iso20022;
import digital.payments.hub.paynet.models;

# Call paynet proxy resolution service to resolve the proxy.
#
# + proxyEnquiryData - supplementary data to resolve the proxy
# + return - proxy lookup response or error
public isolated function getPaynetProxyResolution(iso20022:SplmtryData[]? proxyEnquiryData) 
    returns models:PrxyLookUpRspnCBFT|error {

    if (proxyEnquiryData == ()) {
        return error("Supplementary data not found. Error while resolving proxy");
    }

    http:Client paynetClient = check new (PROXY_RESOLUTION_ENDPOINT);
    
    string secondaryIdType = "";
    string secondaryId = "";
    string bicCode = "";
    time:Utc utcTime = time:utcNow();
    time:Civil date = time:utcToCivil(utcTime);
    string currentDate = date.year.toString() + date.month.toString().padZero(2) + date.day.toString().padZero(2);
    string originator = "O";
    string channelCode = "RB";
    int randomNumber = check random:createIntInRange(1, 99999999);
    string sequenceNumber = randomNumber.toString().padZero(8);

    foreach iso20022:SplmtryData item in proxyEnquiryData {
        if item.Envlp.key == "002" {
            bicCode = item.Envlp.value;
            continue;
        }
        if item.Envlp.key == "011" {
            secondaryIdType = item.Envlp.value;
            continue;
        }
        if item.Envlp.key == "012" {
            secondaryId = item.Envlp.value;
            continue;
        }
    }

    if (bicCode == "" || secondaryIdType == "" || secondaryId == "") {
        return error("Error while resolving proxy. Required data not found");
    }

    string xBusinessMsgId = currentDate + bicCode + PROXY_RESOLUTION_ENQUIRY_TRANSACTION_CODE + originator 
        + channelCode + sequenceNumber;
    models:PrxyLookUpRspnCBFT response = check paynetClient->/[secondaryIdType]/[secondaryId]({
            Accept: mime:APPLICATION_JSON,
            Authorization: "Bearer 123",
            "X-Business-Message-Id": xBusinessMsgId,
            "X-Client-Id": "123456",
            "X-Gps-Coordinates": "3.1234, 101.1234",
            "X-Ip-Address": "1"
    });
    log:printDebug("Response received from Paynet: " + response.toBalString());
    return response;
}

