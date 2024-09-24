// Copyright 2024 [name of copyright owner]
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ballerina/http;
import ballerina/lang.runtime;
import ballerina/log;
import ballerina/tcp;
import ballerina/time;
import ballerina/uuid;

http:Client hubClient = check new ("localhost:9090"); //ToDo: Remove
public http:Client paymentNetworkClient = check new ("localhost:9092"); //ToDo: Remove
map<http:Client> httpClientMap = {};

public function initializeDriverListeners(DriverConfig driverConfig, tcp:ConnectionService|
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

public function initializeDriverHttpClients(string? hubUrl, string? paymentNetworkUrl) returns error? {

    if (hubUrl is string && paymentNetworkUrl is string) {
        hubClient = check new (hubUrl);
        paymentNetworkClient = check new (paymentNetworkUrl);
    }
}

public function initializeDestinationDriverClients() returns error? {

    // ToDo: This should be called by a periodic scheduler
    Metadata[] metadataList = check getdriverMetadataFromHub();

    foreach var metadata in metadataList {
        http:Client driverHttpClient = check new (metadata.paymentEndpoint);
        // Add the client to the map with countryCode as the key
        httpClientMap[metadata.countryCode] = driverHttpClient;
        log:printInfo("Http client for the destination " + metadata.countryCode + " created");
    }
}

public function registerDriverAtHub(string driverName, string countryCode, string paymentEndpoint) returns error? {

    log:printInfo("Registering driver " + driverName + " at payments hub."); // todo - do we need paymentEndpoint??
    json registerResponse = check hubClient->/payments\-hub/register.post({
        driverName: driverName,
        countryCode: countryCode,
        paymentEndpoint: paymentEndpoint
    });

    // ToDo: Add error handling and retry logic
    log:printInfo("\nRegistration response from hub: " + registerResponse.toJsonString());

}

public function sendToDestinationDriver(string countryCode, json payload, string correlationId) returns
    DestinationResponse|error {

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
            DestinationResponse destinationResponse = {
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

public function sendToPaymentNetwork(json payload) returns json|error? {

    http:Request request = new;
    request.setHeader("Content-Type", "application/json");
    request.setPayload(payload);
    http:Response response = check paymentNetworkClient->/payment.post(request);
    return response.getJsonPayload();
}

public function publishEvent(Event event) {

    log:printInfo("Publishing event to payments hub.");
    json|http:ClientError eventResponse = hubClient->/payments\-hub/events.post(event.toJson());
    if (eventResponse is error) {
        log:printInfo("Error occurred when publishing event");
    } else {
        log:printInfo("\n Event published:" + event.toJsonString());
    }
}

public function createEvent(string correlationId, EventType eventType, string origin, string destination,
        string status, string errorMessage) returns Event {

    time:Utc utc = time:utcNow();
    string currentTimestamp = time:utcToString(utc);
    string id = uuid:createType4AsString();

    Event event = {
        id: id,
        correlationId: correlationId,
        eventType: eventType,
        origin: origin,
        destination: destination,
        eventTimestamp: currentTimestamp,
        status: status,
        errorMessage: errorMessage
    };

    return event;
}

function getdriverMetadataFromHub() returns Metadata[]|error {

    Metadata[]|http:ClientError metadataList = hubClient->get("/payments-hub/metadata");

    if (metadataList is error) {
        log:printError("Error occurred when getting driver metadata from payments hub");
        return error("Error occurred when getting driver metadata from payments hub", metadataList);
    }
    return metadataList;
}

function initiateNewTCPListener(DriverConfig driver, tcp:ConnectionService driverTCPConnectionService) returns error? {

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

public function initiateNewHTTPListener(DriverConfig driver, HTTPConnectionService driverHTTPConnectionService)
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
