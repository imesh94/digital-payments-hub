import ballerina/http;
import ballerina/log;

service / on new http:Listener(9093) {
    isolated resource function post inbound_payload(http:Caller caller, http:Request req) returns error? {

        log:printInfo("Sample driver received payment request");
        // Publish event

        // Send request to payment network
        log:printInfo("Sending request to the payment network");

        log:printInfo("Received response from the payment network");
        json paymentNetworkResponse = {
            "status": "success",
            "message": "Payment processed successfully"
        };

        // Return response;
        log:printInfo("Responding to the source driver");
        check caller->respond(paymentNetworkResponse);
    };
}
