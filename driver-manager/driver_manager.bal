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
import ballerina/io;
import ballerina/log;

configurable int port = 9090;

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

type Metadata readonly & record {
    string driverName;
    string countryCode;
    string paymentEndpoint;
};

EventPublisher eventPublisher = new EventPublisher("./driver-manager-events.log");

service /payments\-hub on new http:Listener(port) {

    map<Metadata> metadataMap = {};

    resource function get metadata() returns Metadata[] {

        log:printInfo("Received metadata request for all countries");
        Metadata[] metadataArray = self.metadataMap.toArray();
        return metadataArray;
    }

    resource function get metadata/[string countryCode]() returns Metadata|http:NotFound {

        log:printInfo("Received metadata request for country code " + countryCode);
        Metadata? metadata = self.metadataMap[countryCode];
        if metadata is () {
            return http:NOT_FOUND;
        } else {
            return metadata;
        }
    }

    resource function post register(@http:Payload Metadata metadata) returns Metadata {

        log:printInfo("Received driver registration request");
        self.metadataMap[metadata.countryCode] = metadata;
        log:printInfo(metadata.driverName + " driver registered in payments hub with code " + metadata.countryCode);
        return metadata;
    }

    resource function post events(@http:Payload Event event) returns http:Response {

        log:printInfo("Publishing event");
        http:Response res = new;
        eventPublisher.publishEvent(event);
        res.statusCode = http:STATUS_OK;
        res.setPayload({message: "Event published successfully."});
        return res;
    }
}

public class EventPublisher {

    string filePath;

    function init(string filePath) {
        self.filePath = filePath;
    }

    function publishEvent(Event event) {

        json eventJson = event.toJson();
        string eventJsonString = eventJson.toString();
        string logEntry = eventJsonString + "\n";

        // Append the log entry to the file
        io:Error? publishingError = io:fileWriteString(self.filePath, logEntry, io:APPEND);

        if (publishingError is io:Error) {
            log:printError("Error occurred while publishing event", publishingError);
        } else {
            log:printInfo("Event successfully published");
        }
    }

}
