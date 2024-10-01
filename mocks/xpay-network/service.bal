import ballerina/io;
import ballerina/lang.array;
import ballerina/tcp;

public function main() returns error? {

    // Create a new TCP client by providing the `remoteHost` and `remotePort`.
    // Optionally, you can provide the interface that the socket needs to bind 
    // and the timeout in seconds, which specifies the read timeout value.
    // tcp:Client client = check new ("localhost", 3000, localHost = "localhost", timeout = 5);
    string host = "localhost";
    int port = 8085;
    tcp:Client socketClient = check new (host, port, timeout = 30);

    byte[] proxyData = [0, 0, 1, 11, 73, 83, 79, 49, 57, 56, 55, 51, 48, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 48, 50, 48, 48, 178, 58, 196, 129, 8, 0, 128, 16, 0, 0, 0, 0, 6, 0, 1, 0, 51, 49, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 57, 51, 48, 49, 52, 51, 54, 50, 57, 54, 54, 53, 48, 49, 55, 50, 49, 48, 52, 53, 57, 48, 57, 51, 48, 49, 48, 48, 49, 49, 48, 48, 49, 54, 48, 49, 51, 48, 49, 50, 48, 48, 48, 52, 54, 48, 48, 48, 52, 50, 55, 52, 50, 48, 48, 52, 53, 48, 56, 51, 49, 52, 52, 48, 50, 49, 49, 57, 48, 49, 49, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 48, 48, 48, 50, 48, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 49, 48, 48, 52, 48, 49, 49, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 48, 48, 53, 48, 48, 52, 57, 48, 48, 48, 48, 48, 54, 48, 48, 52, 54, 48, 48, 48, 48, 48, 55, 48, 48, 52, 57, 48, 48, 49, 48, 49, 48, 48, 48, 51, 49, 50, 51, 48, 49, 49, 48, 48, 52, 77, 66, 78, 79, 48, 49, 50, 48, 49, 51, 48, 48, 54, 48, 52, 49, 50, 51, 52, 49, 50, 51, 52, 48, 49, 51, 48, 48, 50, 48, 48];
    // Send the proxy request content to the server.
    io:println(string `Sending proxy request to ${host}:${port}. Message: ${"\n"}${proxyData.toBase16()}`);
    check socketClient->writeBytes(proxyData);

    // Read the response from the server.
    readonly & byte[] receivedData = check socketClient->readBytes();
    io:println(string `Received proxy request response. Message: ${"\n"}${array:toBase16(receivedData)}`);

    // Close the connection between the server and the client.
    check socketClient->close();
}
