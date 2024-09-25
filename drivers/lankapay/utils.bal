// Copyright 2024 [name of copyright owner]

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import ballerina/http;
# Maps the country code to the destination country. The mapping is specific to LankaPay.
#
# + countryCode - country code
# + return - destination country
function getDestinationCountry(string countryCode) returns string|error {
    match countryCode {
        "9001" => { return "MY"; }
        _ => { return error("Error while resolving destination country. Unknown country code : " + countryCode); }
    } 
};

public isolated service class ResponseErrorInterceptor {
    *http:ResponseErrorInterceptor;
    remote isolated function interceptResponseError(error err) returns http:BadRequest {
        // In this case, all the errors are sent as `400 BadRequest` responses with a customized
        // media type and body. Moreover, you can send different status code responses according to
        // the error type.        
        return {
            mediaType: "application/json",
            // todo - use camt029 
            body: {message: err.message()}
        };
    }
}