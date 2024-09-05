import ballerinax/financial.iso20022;
import digital.payments.hub.paynet.util;
import digital.payments.hub.paynet.models;
import ballerina/log;

public isolated function outbound(anydata iso20022Msg) returns anydata|error {

    if (iso20022Msg is iso20022:FIToFICstmrCdtTrf) {
        iso20022:FIToFICstmrCdtTrf isoPacs008Msg =  check iso20022Msg.cloneWithType(iso20022:FIToFICstmrCdtTrf);
        // Differentiate proxy resolution and fund transfer request
        if (isoPacs008Msg.GrpHdr.MsgId.startsWith(util:PROXY_RESOLUTION_PROCESSING_CODE)) {
            // proxy request
            models:PrxyLookUpRspnCBFT|error paynetProxyResolution = util:getPaynetProxyResolution(isoPacs008Msg.SplmtryData);
            if (paynetProxyResolution is error) {
                log:printError("Error while resolving proxy: " + paynetProxyResolution.message());
                return paynetProxyResolution;
            }
            log:printInfo("Paynet Proxy Resolution: " + paynetProxyResolution.toBalString());
            return paynetProxyResolution;
        } else {
            // fund transfer request
            // todo
            return isoPacs008Msg;
        }
    } else {
        log:printError("Error while converting to ISO 20022 message");
        return "Error while converting to ISO 20022 message";
    }
}