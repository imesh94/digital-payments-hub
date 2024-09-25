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
import ballerina/log;

import digitalpaymentshub/drivers.util;

service / on new http:Listener(9093) {
    resource function post inbound_payload(http:Caller caller, http:Request req) returns error? {

        log:printInfo("Sample driver received payment request");
        string|http:HeaderNotFoundError correlationIdHeader = req.getHeader("X-Correlation-ID");
        string correlationId = "N/A";

        if (correlationIdHeader is string) {
            correlationId = correlationIdHeader;
        }

        // Publish event
        util:Event receivedEvent = util:createEvent(correlationId, util:RECEIVED_FROM_SOURCE_DRIVER,
                "sample-origin", "sample-destination", "success", "N/A");
        util:publishEvent(receivedEvent);
        //createEvent(string correlationId, EventType eventType, string origin, string destination,
        //string eventTimestamp, string status, string errorMessage)

        // Send request to payment network
        log:printInfo("Sending request to the payment network");

        log:printInfo("Received response from the payment network");
        json paymentNetworkResponse = {
            "status": "success",
            "message": "Payment processed successfully"
        };

        http:Response res = new;
        res.setPayload(paymentNetworkResponse);

        // Add the X-Correlation-ID header to the response if present
        if correlationId is string {
            res.setHeader("X-Correlation-ID", correlationId);
        }
        res.statusCode = 200;
        // Return response
        log:printInfo("Responding to the source driver");
        check caller->respond(res);
    };
}
