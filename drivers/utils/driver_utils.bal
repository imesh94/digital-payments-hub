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
import ballerina/task;
import ballerina/tcp;

import digitalpaymentshub/payments_hub.models;

http:Client hubClient = check new ("localhost:9090"); //ToDo: Remove
public http:Client paymentNetworkClient = check new ("localhost:9092"); //ToDo: Remove
map<http:Client> httpClientMap = {};
models:DriverRegisterModel[] metadataList = [];

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
# + driverMetadata - populated driver metadata record
# + return - error
public function registerDriverAtHub(models:DriverRegisterModel driverRegisterMetadata) returns error? {

    log:printInfo(string `[Driver Utils] Registering driver " + driverRegisterMetadata.driverName + " at payments hub.`, 
        DriverInfo = driverRegisterMetadata.toJson());
    models:DriverMetadata registerResponse = check hubClient->/payments\-hub/register.post(driverRegisterMetadata);

    // ToDo: Add error handling and retry logic
    log:printInfo("\nRegistration response from hub: " + registerResponse.toString());

}

# Send message to another driver.
#
# + countryCode - country code of the destination driver  
# + payload - request payload  
# + correlationId - correlation-id to track the transaction
# + return - response from the destination driver | error
public function sendToHub(string countryCode, json payload, string correlationId) returns
    json|error {

    http:Client? destinationClient = httpClientMap[countryCode];

    if (destinationClient is http:Client) {
        http:Request request = new;
        request.setHeader("Content-Type", "application/json");
        request.setHeader("X-Correlation-ID", correlationId);
        request.setPayload(payload);
        http:Response response = check destinationClient->/transact.post(request);

        int responseStatusCode = response.statusCode;
        // string|http:HeaderNotFoundError responseCorrelationId = response.getHeader("X-Correlation-ID");
        json|http:ClientError responsePayload = response.getJsonPayload();

        // if (responseStatusCode == 200 && responseCorrelationId is string && responsePayload is json) {
        if (responseStatusCode == 200 && responsePayload is json) {
            json destinationResponse = {
                correlationId: correlationId,
                responsePayload: responsePayload
            };
            return destinationResponse;
        } else if (responsePayload is json) {
            log:printError("Error returned from the destination driver");
            return error(responsePayload.toString() + " CorrelationID: " + correlationId);
        } else if (responsePayload is error) {
            log:printError("Error occurred while forwarding request to the destination driver");
            return responsePayload;
        }
    } else {
        string errorMessage = "Http client for the destination " + countryCode + " not found";
        log:printError(errorMessage);
        return error(errorMessage);
    }
}

# Send request to the payment network.
#
# + payload - request payload
# + return - response as a json | error
public function sendToPaymentNetwork(json payload) returns json|error? {

    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setPayload(payload);
    http:Response response = check paymentNetworkClient->/payment.post(request);
    return response.getJsonPayload();
}

# Get a ppopulated driver metadata record with given arguments
#
# + driverName - name of the driver  
# + countryCode - country code of the driver  
# + paymentsEndpoint - payments endpoint which can be called by source drivers
# + return - populated driver metadata record
public function createDriverRegisterModel(string driverName, string countryCode, 
    models:AccountsLookUp[]? accountsLookUp, string driverGatewayUrl) returns models:DriverRegisterModel {

    models:DriverRegisterModel driverMetadata = {

        driverName: driverName,
        countryCode: countryCode,
        accountsLookUp: accountsLookUp,
        driverGatewayUrl: driverGatewayUrl

    };

    return driverMetadata;
}

# Get metadata of the registered drivers at payments hub.
#
# + return - driver metadata | error
function getdriverMetadataFromHub() returns models:DriverRegisterModel[]|error {

    models:DriverRegisterModel[]|http:ClientError metadataList = hubClient->get("/payments-hub/metadata");

    if (metadataList is error) {
        log:printError("Error occurred when getting driver metadata from payments hub");
        return error("Error occurred when getting driver metadata from payments hub", metadataList);
    }
    return metadataList;
}

# Initiate a new TCP listener with the given connection service.
#
# + driver - configurations of the driver
# + driverTCPConnectionService - customized tcp connection service of the driver
# + return - error
function initiateNewTCPListener(models:DriverConfig driver, tcp:ConnectionService driverTCPConnectionService) returns error? {

    tcp:Listener tcpListener = check new tcp:Listener(driver.inbound.port);
    tcp:Service tcpService = service object {
        function onConnect(tcp:Caller caller) returns tcp:ConnectionService|error {
            log:printInfo("Client connected to port: " + driver.inbound.port.toString());
            return driverTCPConnectionService;
        }
    };
    check tcpListener.attach(tcpService);
    check tcpListener.'start();
    runtime:registerListener(tcpListener);
    log:printInfo("Started " + driver.name + " TCP listener on port: " + driver.inbound.port.toString());
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
            log:printInfo("Client connected to HTTP service on port: " + driver.inbound.port.toString());
            check driverHTTPConnectionService.onRequest(caller, req);
        }
    };

    check httpListener.attach(httpService);
    check httpListener.'start();
    runtime:registerListener(httpListener);
    log:printInfo("Started " + driver.name + " HTTP listener on port: " + driver.inbound.port.toString());
}

# Represent HTTP Listener ConnectionService service type.
public type HTTPConnectionService distinct service object {

    public function onRequest(http:Caller caller, http:Request req) returns error?;
};

# Perioic job to initialize http clients to communicate with destination drivers.
# This job will only initialize http clients if there are any new drivers registered
# at the payments hub
class DestinationClientInitializationJob {
    *task:Job;

    public function execute() {

        models:DriverRegisterModel[]|error newMetadataList = getdriverMetadataFromHub();

        if (newMetadataList is models:DriverRegisterModel[]) {
            if (metadataList == newMetadataList) {
                log:printDebug("No change in cached destination driver metadata. " +
                        "No requirement to create new http clients.");
                return;
            }
            log:printInfo("Creating http clients for destination drivers.");
            metadataList = newMetadataList;
            httpClientMap.removeAll();
            foreach var driverInfo in metadataList {
                string countryCode = driverInfo.countryCode;
                http:Client|error destinationHttpClient = new (driverInfo.driverGatewayUrl);
                // Add the client to the map with countryCode as the key
                if (destinationHttpClient is http:Client) {
                    httpClientMap[countryCode] = destinationHttpClient;
                    log:printInfo("Http client for the destination " + countryCode + " created");
                } else {
                    log:printError("Error occurred while creating destination http client.",
                            destinationHttpClient);
                }
            }
        } else {
            log:printError("Error occurred while getting metadata of drivers from payment hub.", newMetadataList);
        }
    }
}
