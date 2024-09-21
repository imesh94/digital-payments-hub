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
