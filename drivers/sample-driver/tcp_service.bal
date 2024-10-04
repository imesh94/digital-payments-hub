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

configurable models:DriverConfig driver = ?;
configurable models:PaymentsHubConfig payments_hub = ?;

public function main() returns error? {

    string driverGatewayUrl = driver.driver_api.gateway_url;

    models:AccountsLookUp[] accountsLookUp = [
        {'type: "MBNO", description: "Mobile Number"},
        {'type: "NIC", description: "National Identity Card Number"}
    ];
    models:DriverRegisterModel driverMetadata = utils:createDriverRegisterModel(driver.name, driver.code,
            accountsLookUp, driverGatewayUrl);
    check utils:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
    check utils:initializeHubClient(payments_hub.base_url);
    check utils:registerDriverAtHub(driverMetadata);
    //todo initialize outbound client
}

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {

        log:printInfo("Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[] {

        log:printDebug("Received inbound request");
        string correlationId = uuid:createType4AsString();

        // Convert data to iso20022
        json sampleJson = {"data": "sample data"};

        // Send to destination driver
        log:printDebug("Forwarding request to destination driver");
        json|error? destinationResponse = utils:sendToHub(
                "MY", sampleJson, "correlation-id");
        if (destinationResponse is json) {
            log:printDebug(
                    "Response received from destination driver: " + destinationResponse.toString() +
                    " CorrelationId: " + correlationId);
        } else {
            log:printError("Error occurred while getting response from the destination driver", destinationResponse);
            return self.sendError("errorCode");
        }

        // Convert response to iso8583

        // Respond
        log:printDebug("Responding to source");
        return data;
    }

    function onError(tcp:Error err) {
        log:printError("An error occurred", 'error = err);
    }

    function onClose() {
        log:printInfo("Client left");
    }

    function sendError(string errorCode) returns byte[] {
        json response = {"error": errorCode};
        return response.toString().toBytes();
    }
}
