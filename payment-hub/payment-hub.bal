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

service / on new http:Listener(9095) {

    resource function post account\-lookup(AccountLookupRequest payload) returns AccountLookupResponse|ErrorResponse {

        log:printInfo("Received lookup request payload: " + payload.toJsonString());

        // Creating a sample error response
        ErrorResponse errorResponse = {
            body: {
                errorCode: "TXN001",
                errorDescription: "Invalid transaction format",
                metadata: {"transactionId": "12345", "field": "amount"}
            }
        };

        return errorResponse;
    }

    resource function post transactions(TransactionsRequest payload) returns ErrorResponse {

        log:printInfo("Received transactions request payload: " + payload.toJsonString());

        // Creating a sample error response
        ErrorResponse errorResponse = {
            body: {
                errorCode: "TXN001",
                errorDescription: "Invalid transaction format",
                metadata: {"transactionId": "12345", "field": "amount"}
            }
        };

        return errorResponse;
    }
}
