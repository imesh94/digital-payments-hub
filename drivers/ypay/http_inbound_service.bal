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

import digitalpaymentshub/drivers.utils;

public service class DriverHTTPConnectionService {
    *utils:HTTPConnectionService;

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
