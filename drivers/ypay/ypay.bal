// Copyright (c) 2024 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/mime;
import ballerina/log;

import drivers.ypay.models as ypay_models;
import digitalpaymentshub/payments_hub.models;
import ballerinax/financial.iso20022;


public function handleInbound(json data) returns string? {
    // Todo - implement the logic
    return;
};

function getProxyResolution(models:AccountLookupRequest accountLookupRequest) 
    returns ypay_models:PrxyLookUpRspnCBFT|error {
    
    map<string>? metadata = accountLookupRequest.metadata;
    if (metadata is () || metadata.length() == 0) {
        log:printError("[YPay Driver] Metadata not found in the request");
        return error("Metadata not found in the request");
    }
    string bicCode = metadata.hasKey(BIC_CODE) ? metadata.get(BIC_CODE) : "";
    string proxyType = accountLookupRequest.proxyType;
    string proxy = accountLookupRequest.proxyValue;

    if (bicCode == "" || proxyType == "" || proxy == "") {
        log:printError("[YPay Driver] Error while resolving proxy. Required data not found");
        return error("Error while resolving proxy. Required data not found");
    }

    string xBusinessMsgId = check generateXBusinessMsgId(bicCode);
    ypay_models:PrxyLookUpRspnCBFT response = 
        check paymentNetworkClient->/v1/picasso\-guard/banks/nad/v2/resolution/[proxyType]/[proxy]({
            Accept: mime:APPLICATION_JSON,
            Authorization: "Bearer 12345-6789",
            "X-Business-Message-Id": xBusinessMsgId,
            "X-Client-Id": "123456",
            "X-Gps-Coordinates": "3.1234, 101.1234",
            "X-Ip-Address": "172.110.12.10"
        });
    log:printDebug(string `[YPay Driver] Response received from Ypay network`, Response = response.toBalString());
    return response;
}

function postPaynetProxyRegistration(iso20022:FIToFICstmrCdtTrf isoPacs008Msg) 
    returns ypay_models:fundTransferResponse|error {

    string bicCode = isoPacs008Msg.CdtTrfTxInf[0].DbtrAcct?.Id?.Othr?.Id ?: "";
    string xBusinessMsgId = check generateXBusinessMsgId(bicCode);
    map<string> headers = {
        Accept: mime:APPLICATION_JSON,
        Authorization: "Bearer 12345-6789",
        "X-Business-Message-Id": xBusinessMsgId,
        "X-Client-Id": "123456",
        "X-Gps-Coordinates": "3.1234, 101.1234",
        "X-Ip-Address": "172.10.100.23"
    };
    ypay_models:fundTransferResponse response = 
        check paymentNetworkClient->post("/v1/picasso-guard/banks/nad/v2/register", isoPacs008Msg, headers);
    log:printDebug(string `[Ypay driver] Response received from Ypay Network`, Response = response.toBalString());
    return response;
};
