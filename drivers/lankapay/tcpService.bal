// Copyright 2024 [name of copyright owner]

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import ballerina/log;
import ballerina/tcp;
import digitalpaymentshub/drivers.util;

configurable util:DriverConfig driver = ?;

public function main() returns error? {
    // register the service
    check util:registerDriverAtHub(driver.name, driver.code, driver.outbound.baseUrl);
    // connection initialization
    check util:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
}

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {
        log:printInfo("Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns byte[]|error|tcp:Error? {

        byte[] response = handleInbound(data);
        log:printDebug("Responding to origin of the payment");
        return response;
    }

    function onError(tcp:Error err) {

        log:printError("An error occurred", 'error = err);
    }

    function onClose() {

        log:printInfo("Client left");
    }
}
