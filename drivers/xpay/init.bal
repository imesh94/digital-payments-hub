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

import ballerina/file;
import ballerina/log;

import ballerinax/financial.iso8583;

import digitalpaymentshub/drivers.utils;
import digitalpaymentshub/payments_hub.models;


configurable models:DriverConfig driver = ?;
configurable models:PaymentsHubConfig payments_hub = ?;

public function main() returns error? {

    // initialize 8583 library with custom xml
    string|file:Error xmlFilePath = file:getAbsolutePath("resources/jposdefv87.xml");
    if xmlFilePath is string {
        log:printInfo("Initializing ISO 8583 library with the configuration file: " + xmlFilePath);
        check iso8583:initialize(xmlFilePath);
    } else {
        log:printWarn("Error occurred while getting the absolute path of the ISO 8583 configuration file. " +
                "Loading with default configurations.");
    }
    // connection initialization
    check utils:initializeDriverListeners(driver, new DriverTCPConnectionService(driver.name));
    // http client initialization
    check utils:initializeHubClient(payments_hub.base_url);
        // register the service
    string driverGatewayUrl = driver.driver_api.gateway_url;
    models:DriverRegisterModel driverMetadata = utils:createDriverRegisterModel(driver.name, driver.code, [],
        driverGatewayUrl);
    //todo initialize outbound client
    check utils:registerDriverAtHub(driverMetadata);
}