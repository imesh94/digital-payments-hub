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

import ballerina/io;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

public class KafkaEventPublisher {

    private final kafka:Producer kafkaPublisher;
    string topic = "payments-hub-driver-manager";

    function init() returns error? {
        self.kafkaPublisher = check new (kafka:DEFAULT_URL);
    }

    function publishEvent(EventType eventType, string origin, string destination, string correlationId) {

        string eventJson = createEventJson(eventType, origin, destination, correlationId).toString();

        kafka:Error? publishingError = self.kafkaPublisher->send({
            topic: self.topic,
            value: eventJson
        });

        if (publishingError is kafka:Error) {
            log:printError("Error occurred while publishing event", publishingError);
        } else {
            log:printDebug("Event successfully published");
        }
    }
}

public class FileEventPublisher {
    string filePath;

    function init(string filePath) {
        self.filePath = filePath;
    }

    function publishEvent(EventType eventType, string origin, string destination, string correlationId) {

        json eventJson = createEventJson(eventType, origin, destination, correlationId);
        string eventJsonString = eventJson.toString();
        string logEntry = eventJsonString + "\n";

        // Append the log entry to the file
        io:Error? publishingError = io:fileWriteString(self.filePath, logEntry, io:APPEND);

        if (publishingError is io:Error) {
            log:printError("Error occurred while publishing event", publishingError);
        } else {
            log:printDebug("Event successfully published");
        }
    }

}

function createEventJson(EventType eventType, string origin, string destination, string correlationId)
    returns json {

    string timestamp = time:utcNow().toString();
    string id = uuid:createType4AsString();

    json eventJsonObject = {
        "id": id,
        "correlationId": correlationId,
        "eventType": eventType,
        "origin": origin,
        "destination": destination,
        "eventTimestamp": timestamp,
        "status": "",
        "errorMessage": ""
    };

    return eventJsonObject;
}
