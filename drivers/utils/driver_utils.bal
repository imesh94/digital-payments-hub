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
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/tcp;

import digitalpaymentshub/payments_hub.models;

http:Client hubClient = check new ("localhost:9090"); //ToDo: Remove
public http:Client paymentNetworkClient = check new ("localhost:9092"); //ToDo: Remove

# Initialize http/tcp listeners for the driver based on configurations.
#
# + driverConfig - driver configurations 
# + driverConnectionService - http/tcp connection service
# + return - error
public function initializeDriverListeners(models:DriverConfig driverConfig, tcp:ConnectionService|
        HTTPConnectionService driverConnectionService)
    returns error? {

    if ("tcp" == driverConfig.inbound.transport && driverConnectionService is tcp:ConnectionService) {
        check initiateNewTCPListener(driverConfig, driverConnectionService);
    } else if ("http" == driverConfig.inbound.transport && driverConnectionService is HTTPConnectionService) {
        check initiateNewHTTPListener(driverConfig, driverConnectionService);
    } else {
        return error("Invalid transport configured for the driver.");
    }
}

# Initialize http clients to communicate with the payments hub.
#
# + hubUrl - url of the payments hub  
# + return - error
public function initializeHubClient(string hubUrl) returns error? {

    hubClient = check new (hubUrl);
}

# Register driver at payments hub.
#
# + driverRegisterMetadata - populated driver metadata record
# + return - error
public function registerDriverAtHub(models:DriverRegisterModel driverRegisterMetadata) returns error? {

    log:printInfo(string `[Driver Utils] Registering driver ${driverRegisterMetadata.driverName} at payments hub.`,
            DriverInfo = driverRegisterMetadata.toJson());
    models:DriverMetadata registerResponse = check hubClient->/payments\-hub/register.post(driverRegisterMetadata);

    // ToDo: Add error handling and retry logic
    log:printInfo(string `[Driver Utils] Registration response received.`, Response = registerResponse.toJson());

}

# Send message to another driver.
#
# + countryCode - country code of the destination driver  
# + payload - request payload  
# + correlationId - correlation-id to track the transaction
# + return - response from the destination driver | error
public function sendPaymentRequestToHub(string countryCode, models:TransactionsRequest payload, string correlationId)
    returns json|error {

    map<string> headersMap = {
        X\-Correlation\-ID: correlationId,
        Country\-Code: countryCode
    };
    http:Response response = check hubClient->/payments\-hub/cross\-border/payments.post(payload, headersMap);
    int responseStatusCode = response.statusCode;
    json|http:ClientError responsePayload = response.getJsonPayload();

    if ((responseStatusCode == 200 || responseStatusCode == 201) && responsePayload is json) {
        return responsePayload;
    } else if (responsePayload is json) {
        log:printError("[Driver Utils] Error returned from the payments hub");
        return error(string `${responsePayload.toString()}. CorrelationID: ${correlationId}`);
    }
    log:printError("[Driver Utils] Error occurred while forwarding request to the payments hub");
    return responsePayload;
}

public function sendAccountsLookUpRequestToHub(string countryCode, models:AccountLookupRequest payload,
        string correlationId) returns json|error {

    map<string> headersMap = {
        X\-Correlation\-ID: correlationId,
        Country\-Code: countryCode
    };
    http:Response response = check hubClient->/payments\-hub/cross\-border/accounts/look\-up.post(payload, headersMap);
    int responseStatusCode = response.statusCode;
    json|http:ClientError responsePayload = response.getJsonPayload();

    if ((responseStatusCode == 200 || responseStatusCode == 201) && responsePayload is json) {
        return responsePayload;
    } else if (responsePayload is json) {
        log:printError("[Driver Utils] Error returned from the payments hub");
        return error(string `${responsePayload.toString()}. CorrelationID: ${correlationId}`);
    }
    log:printError("[Driver Utils] Error occurred while forwarding request to the payments hub");
    return responsePayload;
}

// # Send request to the payment network.
// #
// # + payload - request payload
// # + return - response as a json | error
// public function sendToPaymentNetwork(json payload) returns json|error? {

//     http:Request request = new;
//     request.setHeader("Content-Type", "application/json");
//     request.setPayload(payload);
//     http:Response response = check paymentNetworkClient->/payment.post(request);
//     return response.getJsonPayload();
// }

# Get a ppopulated driver metadata record with given arguments
#
# + driverName - name of the driver  
# + countryCode - country code of the driver  
# + accountsLookUp - accounts look up details
# + driverGatewayUrl - driver gateway url
# + return - populated driver metadata record
public function createDriverRegisterModel(string driverName, string countryCode,
        models:AccountsLookUp[] accountsLookUp, string driverGatewayUrl) returns models:DriverRegisterModel {

    models:DriverRegisterModel driverMetadata = {

        driverName: driverName,
        countryCode: countryCode,
        accountsLookUp: accountsLookUp,
        driverGatewayUrl: driverGatewayUrl

    };

    return driverMetadata;
}

# Initiate a new TCP listener with the given connection service.
#
# + driver - configurations of the driver
# + driverTCPConnectionService - customized tcp connection service of the driver
# + return - error
function initiateNewTCPListener(models:DriverConfig driver, tcp:ConnectionService driverTCPConnectionService)
    returns error? {

    tcp:Listener tcpListener = check new tcp:Listener(driver.inbound.port);
    tcp:Service tcpService = service object {
        function onConnect(tcp:Caller caller) returns tcp:ConnectionService|error {
            log:printInfo("[Driver Utils] Client connected to port: " + driver.inbound.port.toString());
            return driverTCPConnectionService;
        }
    };
    check tcpListener.attach(tcpService);
    check tcpListener.'start();
    runtime:registerListener(tcpListener);
    log:printInfo("[Driver Utils] Started " + driver.name + " TCP listener on port: " + driver.inbound.port.toString());
};

# Initiate a new HTTP listener with the given connection service.
#
# + driver - configurations of the driver
# + driverHTTPConnectionService - customized http connection service of the driver
# + return - error
function initiateNewHTTPListener(models:DriverConfig driver, HTTPConnectionService driverHTTPConnectionService)
    returns error? {

    http:Listener httpListener = check new http:Listener(driver.inbound.port);
    http:Service httpService = service object {
        resource function post .(http:Caller caller, http:Request req) returns error? {
            log:printInfo("[Driver Utils] Client connected to HTTP service on port: " + driver.inbound.port.toString());
            check driverHTTPConnectionService.onRequest(caller, req);
        }
    };

    check httpListener.attach(httpService);
    check httpListener.'start();
    runtime:registerListener(httpListener);
    log:printInfo("[Driver Utils] Started " + driver.name + " HTTP listener on port: " +
            driver.inbound.port.toString());
}

# Represent HTTP Listener ConnectionService service type.
public type HTTPConnectionService distinct service object {

    public function onRequest(http:Caller caller, http:Request req) returns error?;
};
