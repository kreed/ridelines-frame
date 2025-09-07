function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Remove the /rum prefix and forward to the actual RUM endpoint
    if (uri.startsWith('/rum/')) {
        request.uri = uri.substring(4); // Remove '/rum' prefix
    }
    
    return request;
}