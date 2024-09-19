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
import ballerina/log;

http:Client hubClient = check new ("http://localhost:9090");
int inboundPort = 8087;
int paymentPort = 9097;

type Event readonly & record {
    string id;
    string correlationId;
    string eventType;
    string origin;
    string destination;
    string eventTimestamp;
    string status;
    string errorMessage;
};

type DriverMetadata readonly & record {
    string driver;
    string countryCode;
    string inboundEndpoint;
    string paymentEndpoint;
};

public function main() returns error? {
    error? registrationError = registerDriver();

    if (registrationError is error) {
        log:printError("Error occurred while registering driver in payments hub. " + registrationError.message());
    }
}

public function registerDriver() returns error? {

    log:printInfo("Registering driver in payments hub.");
    DriverMetadata driverMetadata = check hubClient->/payments\-hub/register.post({
        driver: "PayNet",
        countryCode: "MY",
        inboundEndpoint: "http://localhost:" + inboundPort.toString(),
        paymentEndpoint: "http://localhost:" + paymentPort.toString()
    });
    log:printInfo("POST request:" + driverMetadata.toJsonString());
}

public function publishEvent() {

    log:printInfo("Publishing event to payments hub.");
    json|http:ClientError event = hubClient->/payments\-hub/events.post({
        id: "randomNumber",
        correlationId: "randomNumber",
        eventType: "SAMPLE_EVENT",
        origin: "PayNet",
        destination: "LankaPay",
        eventTimestamp: "timestamp",
        status: "success",
        errorMessage: "N/A"
    });
    if (event is error) {
        log:printInfo("Error occurred when publishing event");
    } else {
        log:printInfo("\n Event published:" + event.toJsonString());
    }
}

public function getDestinationDriverMetadata(string countryCode) returns DriverMetadata|error? {

    return check hubClient->/payments\-hub/metadata/[countryCode];
}

public function forwardRequestToDestinationDriver(string data, string endpoint) returns json|error? {

    log:printInfo("Sending request to the destination driver");
    http:Client destinationClient = check new (endpoint);

    json payload = {"data": data};
    http:Request request = new;
    request.setHeader(http:CONTENT_TYPE, "application/json");
    request.setJsonPayload(payload);

    http:Response|error response = destinationClient->post("/payments", request);

    if (response is http:Response) {
        json responsePayload = check response.getJsonPayload();
        log:printInfo("Received response from destination driver");
        return responsePayload;
    } else {
        log:printError("Failed to send POST request to the destination driver");
        return response;
    }
}

service / on new http:Listener(inboundPort) {

    resource function post inbound(@http:Payload json data) returns json|error {

        log:printInfo("Received payment request via HTTP: " + data.toJsonString());

        string destinationDriverEndpoint;
        publishEvent();
        log:printInfo("Reading incoming 20022 message");

        log:printInfo("Destination driver metadata not found in cache. Getting metadata from payments hub.");
        DriverMetadata|error? destinationDriverMetadata = getDestinationDriverMetadata("LK");
        if (destinationDriverMetadata is DriverMetadata) {
            destinationDriverEndpoint = destinationDriverMetadata.paymentEndpoint;
        } else {
            log:printError("Error occurred while getting destination driver metadata from payments hub. " +
                    "Aborting transaction.");
            return {
                "status": "failure",
                "message": "Error retrieving destination driver metadata."
            };
        }

        log:printInfo("Destination driver payment endpoint is: " + destinationDriverEndpoint);

        // Forward the request to the destination driver
        json|error? destinationResponse = forwardRequestToDestinationDriver(data.toString(), destinationDriverEndpoint);
        if (destinationResponse is json) {
            log:printInfo("Received response from destination driver: " + destinationResponse.toJsonString());
            return destinationResponse;
        } else {
            log:printError("Error response received from destination driver");
            return {
                "status": "failure",
                "message": "Error occurred while processing the request."
            };
        }
    }
}

// Mocked service to simulate a destination driver listening on port 9591
service / on new http:Listener(paymentPort) {

    resource function post payments(@http:Payload json data) returns json {

        log:printInfo("Received payments request: " + data.toJsonString());

        json response = {
            "status": "success",
            "message": "Payment processed successfully by PayNet",
            "transactionId": "1234567890"
        };

        return response;
    }
}
