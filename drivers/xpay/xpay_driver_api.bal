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

import digitalpaymentshub/payments_hub.models;

service /driver\-api on new http:Listener(driver.driver_api.port) {
    resource function post payments(@http:Header string x\-correlation\-id, models:TransactionsRequest payload)
        returns http:Ok|http:NotImplemented {

        return http:NOT_IMPLEMENTED;
    };

    resource function post accounts/look\-up(@http:Header string x\-correlation\-id,
            models:AccountLookupRequest accountLookupRequest) returns models:AccountLookupResponse|http:NotImplemented {

        return http:NOT_IMPLEMENTED;
    };
}
