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

import ballerina/log;
import ballerina/tcp;
import ballerina/uuid;

import digitalpaymentshub/drivers.utils;
import digitalpaymentshub/payments_hub.models;

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {

        log:printInfo("[Sample driver] Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[] {

        log:printDebug("[Sample driver] Received inbound request");
        string correlationId = uuid:createType4AsString();

        // Convert data to iso20022
        models:TransactionsRequest sampleJson = {
            "data":
                                {
                "id": 1,
                "amount": "1000 USD"
            }
        };

        // Send to destination driver
        log:printDebug("[Sample driver] Forwarding request to payments hub");
        json|error? hubResponse = utils:sendPaymentRequestToHub("SD2", sampleJson, "correlation-id");
        if (hubResponse is json) {
            log:printDebug("[Sample driver] Response received from payments hub: " +
                    hubResponse.toString() + " CorrelationId: " + correlationId);
        } else {
            log:printError("[Sample driver] Error occurred while getting response from the payments hub", hubResponse);
            return self.sendError("errorCode");
        }

        // Convert response to iso8583

        // Respond
        log:printDebug("[Sample driver] Responding to source");
        return data;
    }

    function onError(tcp:Error err) {
        log:printError("[Sample driver] An error occurred", 'error = err);
    }

    function onClose() {
        log:printInfo("[Sample driver] Client left");
    }

    function sendError(string errorCode) returns byte[] {
        json response = {"error": errorCode};
        return response.toString().toBytes();
    }
}
