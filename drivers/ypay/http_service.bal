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

configurable util:DriverConfig driver = ?;
configurable map<string> payment_hub = ?;
configurable map<string> payment_network = ?;

public function main() returns error? {
    // register the service
    string driverOutboundBaseUrl = "http://" + driver.outbound.host + ":" + driver.outbound.port.toString();
    log:printInfo(driver.name + " driver outbound endpoint: https://localhost:" + driver.outbound.port.toString());
    util:DriverMetadata driverMetadata = util:createDriverMetadata(driver.name, driver.code, driverOutboundBaseUrl);
    check util:registerDriverAtHub(driverMetadata);
    // connection initialization
    check util:initializeDriverListeners(driver, new DriverHTTPConnectionService(driver.name));
    // http client initialization
    check util:initializeDestinationDriverClients();
    check util:initializeDriverHttpClients(payment_hub["baseUrl"], payment_network["baseUrl"]);
}

# Driver http client for internal hub communications.
service http:InterceptableService / on new http:Listener(driver.outbound.port) {

    # Receive financial transactions from other drivers and handle the real transaction.
    #
    # + caller - http caller  
    # + req - http request  
    # - returns error if an error occurred
    # + return - return value description
    resource function post transact(http:Caller caller, http:Request req) returns error? {

        // Extract the json payload from the request
        json payload = check req.getJsonPayload();
        string correlationId = check req.getHeader("X-Correlation-ID");
        util:Event receivedEvent = util:createEvent(correlationId, util:RECEIVED_FROM_SOURCE_DRIVER,
                "source-driver", driver.code + "-driver", "success", "N/A");
        util:publishEvent(receivedEvent);
        http:Response response = check handleOutbound(payload, correlationId);
        // return response;
        util:Event forwardingEvent = util:createEvent(correlationId, util:FORWARDING_TO_SOURCE_DRIVER,
                driver.code + "-driver", "destination-driver", "success", "N/A");
        util:publishEvent(forwardingEvent);
        check caller->respond(response);
    }

    public function createInterceptors() returns http:Interceptor|http:Interceptor[] {
        return new ResponseErrorInterceptor();
    }
}

public service class DriverHTTPConnectionService {
    *util:HTTPConnectionService;

    string driverName;

    function init(string driverName) {
        log:printInfo("Initialized new HTTP listener for " + driverName);
        self.driverName = driverName;
    }

    public function onRequest(http:Caller caller, http:Request req) returns error? {

        string contentType = req.getContentType();
        json payload = {};
        boolean isError = false;
        http:Response httpResponse = new;
        if (contentType == "application/json") {
            payload = check req.getJsonPayload();
        } else if (contentType == "application/xml") {
            xml xmlPayload = check req.getXmlPayload();
            payload = xmlPayload.toJson();
        } else {
            log:printError("Invalid content type: " + contentType);
            httpResponse.statusCode = 400;
            httpResponse.setJsonPayload({"error": "Invalid content type: " + contentType});
            isError = true;
        }
        if (!isError) {
            json response = handleInbound(payload);
            httpResponse.statusCode = 200;
            httpResponse.setJsonPayload(response);
        }
        log:printDebug("Responding to origin of the payment");
        check caller->respond(httpResponse);
    }
}
