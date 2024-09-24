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


import ballerina/file;
import ballerina/http;
import ballerina/log;
import ballerina/tcp;
import digitalpaymentshub/drivers.util;
import ballerinax/financial.iso8583;

configurable util:DriverConfig driver = ?;
configurable map<string> payment_hub = ?;
configurable map<string> payment_network = ?;

public function main() returns error? {
    // register the service
    string driverOutboundBaseUrl = "http://" + driver.outbound.host + ":" + driver.outbound.port.toString();
    log:printInfo(driver.name + " driver outbound endpoint: http://localhost:" + driver.outbound.port.toString());
    check util:registerDriverAtHub(driver.name, driver.code, driverOutboundBaseUrl);
    // connection initialization
    check util:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
    // http client initialization
    check util:initializeDestinationDriverClients();
    check util:initializeDriverHttpClients(payment_hub["baseUrl"], payment_network["baseUrl"]);
    // initialize 8583 library with custom xml
    string|file:Error xmlFilePath = file:getAbsolutePath("resources/jposdefv87.xml");
    if xmlFilePath is string {
        check iso8583:initialize(xmlFilePath);
    } else {
        log:printWarn("Error occurred while getting the absolute path of the ISO 8583 configuration file. " + 
            "Loading with default configurations.");
    }
}

# Driver http client for internal hub communications.
service http:InterceptableService / on new http:Listener(driver.outbound.port) {

    # A receiving financial transactions from other drivers and handle the real transaction.
    #
    # + caller - http caller  
    # + req - http request  
    # - returns error if an error occurred
    # + return - return value description
    resource function post transact(http:Caller caller, http:Request req) returns error? {
        // Todo - implement the logic
    }
    public function createInterceptors() returns http:Interceptor|http:Interceptor[] {
        return new ResponseErrorInterceptor();
    }
}

public service class DriverTCPConnectionService {

    *tcp:ConnectionService;
    string driverName;

    function init(string driverName) {
        log:printInfo("Initialized new TCP listener for " + driverName);
        self.driverName = driverName;
    }

    function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {

        byte[] response = handleInbound(data);
        log:printDebug("Responding to origin of the payment");
        check caller->writeBytes(response);
    }

    function onError(tcp:Error err) {

        log:printError("An error occurred", 'error = err);
    }

    function onClose() {

        log:printInfo("Client left");
    }
}
