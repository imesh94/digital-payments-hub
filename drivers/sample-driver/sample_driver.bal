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

import digitalpaymentshub/payment_hub as hub;

service /driver on new http:Listener(9093) {
    resource function post payments(@http:Header string x\-correlation\-id, hub:TransactionsRequest payload)
        returns http:Ok {

        log:printDebug("Sample driver received payment request");
        string correlationId = x\-correlation\-id;

        // Send request to payment network
        log:printDebug("Sending request to the payment network");

        log:printDebug("Received response from the payment network");
        json paymentNetworkResponse = {
            "status": "success",
            "message": "Payment processed successfully"
        };
        http:Ok response = {
            body: paymentNetworkResponse,
            headers: {"correlationId": correlationId}
        };
        // Return response
        log:printDebug("Responding to the source driver");
        return response;
    };

    resource function post account/look\-up(@http:Header string x\-correlation\-id,
            hub:AccountLookupRequest accountLookupRequest) returns hub:AccountLookupResponse {

        log:printDebug("Sample driver received payment request");
        string correlationId = x\-correlation\-id;

        string proxyType = accountLookupRequest.proxyType;
        string proxyValue = accountLookupRequest.proxyValue;
        // Send request to payment network
        log:printDebug("Sending request to the payment network");

        log:printDebug("Received response from the payment network");
        hub:AccountLookupResponse accountLookupResponse = {
            headers: {"correlationId": correlationId},
            body: {
                proxy: {
                    'type: proxyType,
                    value: proxyValue
                },
                account: {
                    agentId: "12345",
                    name: "John Doe",
                    accountId: "1234567890"
                }
            }
        };
        return accountLookupResponse;
    };
}
