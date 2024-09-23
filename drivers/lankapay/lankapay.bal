
<<<<<<< HEAD
import ballerina/constraint;
=======
import digital.payments.hub.util;

>>>>>>> fcd6571 (Rename util package)
import ballerina/http;
import ballerina/log;
import ballerina/uuid;

<<<<<<< HEAD
import ballerinax/financial.iso8583;
import ballerinax/financial.iso20022;

import digitalpaymentshub/drivers.util;
import ballerina/data.jsondata;

# A service representing a network-accessible API
# bound to port `9090`.
service http:InterceptableService / on new http:Listener(9090) {

    # A resource for generating greetings
    # + name - name as a string or nil
    # + return - string name with hello message or error
    resource function get greeting(string? name) returns string|error {
        // Send a response back to the caller.
        if name is () {
            return error("name should not be empty!");
        }
        return string `Hello, ${name}`;
    }
    public function createInterceptors() returns http:Interceptor|http:Interceptor[] {
        return new util:ResponseErrorInterceptor();
    }
}


public function handleInbound(byte[] & readonly data) returns byte[]|error {

    string dataString = check string:fromBytes(data);
    string correlationId = uuid:createType4AsString();

    util:publishEvent("RECEIVED_FROM_SOURCE", driver.name, "DRIVER_MANAGER", correlationId);

    byte[] response = [];
    // parse ISO 8583 message
    anydata|iso8583:ISOError parsedISO8583Msg = iso8583:parse(dataString);

    if (parsedISO8583Msg is iso8583:ISOError) {
        log:printError("Error occurred while parsing the ISO 8583 message", err = parsedISO8583Msg);
        response = ("Error occurred while parsing the ISO 8583 message: " + parsedISO8583Msg.message).toBytes();
    } else {
        map<anydata> parsedISO8583Map = <map<anydata>>parsedISO8583Msg;
        string mti = <string>parsedISO8583Map[MTI];

        match mti {
            TYPE_MTI_0200 => {
                // validate the parsed ISO 8583 message
                iso8583:MTI_0200|error validatedMsg = constraint:validate(parsedISO8583Msg);
                if (validatedMsg is iso8583:MTI_0200) {
                    // transform to ISO 20022 message
                    iso20022:FIToFICstmrCdtTrf|error iso20022Msg = transformMTI200ToISO20022(validatedMsg);
                    if (iso20022Msg is error) {
                        log:printError("Error while transforming to ISO 20022 message: " + iso20022Msg.message());
                        response = ("Error while transforming to ISO 20022 message: " 
                            + iso20022Msg.message()).toBytes();
                    } else {
                        // resolve destination country
                        string|error destinationCountryCode = getDestinationCountry(
                            getDataFromSupplementaryData(iso20022Msg.SplmtryData, DESTINATION_COUNTRY_CODE));
                        if (destinationCountryCode is error) {
                            log:printError("Error while resolving destination country: " 
                                + destinationCountryCode.message());
                            response = ("Error while resolving destination country: " 
                                + destinationCountryCode.message()).toBytes();
                        } else {
                            // send the transformed ISO 20022 message to the destination driver
                            anydata destinationDriverResponse = util:sendToDestinationDriver(iso20022Msg);
                            //transform response
                            iso20022:FIToFIPmtStsRpt|error iso20022Response = 
                                constraint:validate(destinationDriverResponse);
                            if (iso20022Response is error) {
                                log:printError("Error while transforming response to ISO 20022: " 
                                    + iso20022Response.message());
                                response = ("Error while transforming response to ISO 20022: " 
                                    + iso20022Response.message()).toBytes();
                            } else {
                                util:publishEvent("SENT_TO_DESTINATION", driver.name, "DRIVER_MANAGER", correlationId);
                                // transform to ISO 8583 MTO 0210
                                iso8583:MTI_0210|error mti0210msg = transformPacs002toMTI0210(iso20022Response);
                                if (mti0210msg is error) {
                                    log:printError("Error while transforming to ISO 8583 MTI 0210: " 
                                        + mti0210msg.message());
                                    response = ("Error while transforming to ISO 8583 MTI 0210: " 
                                        + mti0210msg.message()).toBytes();
                                } else {
                                    json jsonMsg = check jsondata:toJson(mti0210msg);
                                    string|iso8583:ISOError iso8583Msg = iso8583:encode(jsonMsg);
                                    if (iso8583Msg is iso8583:ISOError) {
                                        log:printError("Error occurred while encoding the ISO 8583 message", 
                                            err = iso8583Msg);
                                        response = ("Error occurred while encoding the ISO 8583 message: " 
                                            + iso8583Msg.message).toBytes();
                                    } else {
                                        response = iso8583Msg.toBytes();
                                    }

                                }
                            }
                        }
                    }
                } else {
                    log:printError("Error while validating incoming message: " + validatedMsg.message());
                    response = ("Error while validating: " + validatedMsg.toBalString()).toBytes();
                }
            }
            _ => {
                log:printError("MTI is not supported");
                response = ("MTI is not supported").toBytes();
            }
        }
    }
    return response;
};


=======
public function main() returns error? {
    error? registrationError = registerDriver();

    if (registrationError is error) {
        log:printError("Error occurred while registering driver in ayments hub. " + registrationError.message());
    }
}

public function publishEvent() {

    log:printInfo("Publishing event to payments hub.");
    json|http:ClientError event = hubClient->/payments\-hub/events.post({
        id: "randomNumber",
        correlationId: "randomNumber",
        eventType: "SAMPLE_EVENT",
        origin: "LankaPay",
        destination: "Paynet",
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

service on new tcp:Listener(inboundPort) {
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        io:println("Client connected to driver: ", caller.remotePort);
        return new DriverInboundService();
    }
}

service class DriverInboundService {
    *tcp:ConnectionService;

    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {

        string destinationDriverEndpoint;
        publishEvent();
        log:printInfo("Reading incoming iso8583 message");

        log:printInfo("Destination driver metadata not found in cache. Getting metadata from payments hub.");
        DriverMetadata|error? destinationDriverMetadata = getDestinationDriverMetadata("MY");
        if (destinationDriverMetadata is DriverMetadata) {
            destinationDriverEndpoint = destinationDriverMetadata.paymentEndpoint;
        } else {
            log:printError("Error occurred while getting destination driver metadata from payments hub. " +
                    "Aborting transaction");
            return;
        }
        log:printInfo("Destination driver payment endpoint is : " + destinationDriverEndpoint);

        json|error? destinationResponse = forwardRequestToDestinationDriver("dummy Data", destinationDriverEndpoint);
        if (destinationResponse is json) {
            string responseString = destinationResponse.toString();
            log:printInfo("Response :" + responseString);
        } else {
            log:printInfo("Error response received from destination driver");
        }

        check caller->writeBytes(data);
    }

    remote function onError(tcp:Error err) {
        log:printError("An error occurred", 'error = err);
    }

    remote function onClose() {
        io:println("Client left");
    }
}

service / on new http:Listener(paymentPort) {

    resource function post payments(@http:Payload json data) returns json {

        log:printInfo("Received payments request: " + data.toJsonString());

        json response = {
            "status": "success",
            "message": "Payment processed successfully by LankaPay",
            "transactionId": "1234567890"
        };

        return response;
    }

}
>>>>>>> fcd6571 (Rename util package)
