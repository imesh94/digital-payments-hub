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

import ballerina/http;
import ballerina/log;

import digitalpaymentshub/payments_hub.models;
import drivers.ypay.models as ypay_models;
import ballerina/constraint;
import ballerinax/financial.iso20022;

service http:InterceptableService /driver\-api on new http:Listener(driver.driver_api.port) {
    resource function post payments(@http:Header string x\-correlation\-id, models:TransactionsRequest payload)
        returns models:TransactionResponse|http:NotImplemented|error {

        // fund transfer request to Ypay
        log:printDebug(string `[Ypay Driver] Fund transfer request received`, CorrelationId = x\-correlation\-id);
        iso20022:FIToFICstmrCdtTrf isoPacs008Msg = check constraint:validate(payload.data);
        ypay_models:fundTransferResponse paynetProxyRegistartionResponse = 
                check postPaynetProxyRegistration(isoPacs008Msg);
        iso20022:FIToFIPmtStsRpt iso20022Response = 
            transformFundTransferResponsetoPacs002(paynetProxyRegistartionResponse, isoPacs008Msg);
        log:printDebug(string `[Ypay Driver] Fund transfer response sent`, CorrelationId = x\-correlation\-id, 
            Response = iso20022Response);
        models:TransactionResponse transactionResponse = {
            body: {
                data: iso20022Response.toJson()
            },
            headers: {
                "X-Correlation-Id": x\-correlation\-id
            }

        };
        return transactionResponse;
    };

    resource function post accounts/look\-up(@http:Header string x\-correlation\-id,
            models:AccountLookupRequest accountLookupRequest) 
            returns models:AccountLookupResponse|http:NotImplemented|error {

        // proxy resolution request to Ypay
        log:printDebug(string `[Ypay Driver] Account lookup request received`, 
            ProxyType = accountLookupRequest.proxyType, ProxyValue = accountLookupRequest.proxyValue, 
            CorrelationId = x\-correlation\-id);
        ypay_models:PrxyLookUpRspnCBFT|error paynetProxyResolution = 
            getProxyResolution(accountLookupRequest);
            if (paynetProxyResolution is error) {
                return error("Error while resolving proxy: " + paynetProxyResolution.message());
            }
            // transform to iso 20022 response pacs 002.001.14
            return transformPrxy004toAccountLookupResponse(paynetProxyResolution);
    };

    public function createInterceptors() returns http:Interceptor|http:Interceptor[] {
        return new ResponseErrorInterceptor();
    }
}
