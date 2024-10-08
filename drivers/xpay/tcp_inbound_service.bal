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

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {

        log:printInfo("[XPay driver] Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[] {

        byte[]|error response = handleInbound(data);
        if (response is error) {
            log:printError("[XPay driver] Error occurred while processing the inbound message", 'error = response);
            return "INTERNAL_SERVER_ERROR".toBytes(); //todo match to a MTI eg: 06XX
        }
        log:printDebug("[XPay driver] Responding to origin of the payment");
        return response;
    }

    function onError(tcp:Error err) {
        log:printError("[XPay driver] An error occurred", 'error = err);
    }

    function onClose() {
        log:printInfo("[XPay driver] Client left");
    }

    function sendError(string errorCode) returns byte[] {
        json response = {"error": errorCode};
        return response.toString().toBytes();
    }
}
