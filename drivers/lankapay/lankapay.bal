import ballerina/constraint;
import ballerina/data.jsondata;
import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerinax/financial.iso20022;
import ballerinax/financial.iso8583;

import digitalpaymentshub/drivers.util;

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

