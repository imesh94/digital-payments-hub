public type Event readonly & record {

    string id;
    string correlationId;
    EventType eventType;
    string origin;
    string destination;
    string eventTimestamp;
    string status;
    string errorMessage;
};

public enum EventType {
    RECEIVED_FROM_SOURCE,
    FORWARDING_TO_DESTINATION_DRIVER,
    RECEIVED_FROM_SOURCE_DRIVER,
    FORWARDING_TO_PAYMENT_NETWORK,
    RECEIVED_FROM_PAYMENT_NETWORK,
    FORWARDING_TO_SOURCE_DRIVER,
    RECEIVED_FROM_DESTINATION_DRIVER,
    RESPONDING_TO_SOURCE
}
