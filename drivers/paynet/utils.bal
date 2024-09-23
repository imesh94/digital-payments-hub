import ballerina/log;
import ballerinax/financial.iso20022;
import ballerina/time;
import ballerina/random;
import ballerina/lang.regexp;

isolated function isProxyRequest(iso20022:SplmtryData[]? supplementaryData) returns boolean {

    if (supplementaryData == ()) {
        log:printDebug("Supplementary data not found. Request will be treated as a fund transfer request");
    } else {
        return supplementaryData.some(item => item.Envlp.id == "ProxyRequest");
    }
    return false;
};

isolated function generateXBusinessMsgId(string bicCode) returns string|error {

    time:Utc utcTime = time:utcNow();
    time:Civil date = time:utcToCivil(utcTime);
    string currentDate = date.year.toString() + date.month.toString().padZero(2) + date.day.toString().padZero(2);
    string originator = "O";
    string channelCode = "RB";
    int randomNumber = check random:createIntInRange(1, 99999999);
    string sequenceNumber = randomNumber.toString().padZero(8);
    return currentDate + bicCode + PROXY_RESOLUTION_ENQUIRY_TRANSACTION_CODE + originator
        + channelCode + sequenceNumber;
};

isolated function resolveProxyType(iso20022:SplmtryData[]? supplementaryData) returns string {

    if (supplementaryData != ()) {
        foreach iso20022:SplmtryData item in supplementaryData {
            // todo how to resolve this name conflict??
            if item.Envlp.id == "Particulars" {
                return item.Envlp.value ?: "";
            }
        }
    }
    return "";
};

isolated function resolveProxy(iso20022:SplmtryData[]? supplementaryData) returns string {

    if (supplementaryData != ()) {
        foreach iso20022:SplmtryData item in supplementaryData {
            // todo how to resolve this name conflict??
            if item.Envlp.id == "Reference" {
                return item.Envlp.value ?: "";
            }
        }
    }
    return "";
};

# Return yyyy-MM-ddTHH:mm:ss.SSS format string.
#
# + return - return value description
isolated function getCurrentDateTime() returns string|error {

    time:Utc utcTime = time:utcNow();
    final string:RegExp seperator = re `.`;
    time:Civil civilDateTime = time:utcToCivil(utcTime);
    return civilDateTime.year.toString() + "-" + civilDateTime.month.toString().padZero(2) + "-"
        + civilDateTime.day.toString().padZero(2) + "T"
        + civilDateTime.hour.toString().padZero(2) + ":" + civilDateTime.minute.toString().padZero(2) + ":"
        + regexp:split(seperator, civilDateTime.second.toString())[0].padZero(2) + "."
        + regexp:split(seperator, civilDateTime.second.toString())[1].padZero(3);

}
