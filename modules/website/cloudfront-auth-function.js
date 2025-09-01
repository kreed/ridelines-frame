/**
 * CloudFront Function for tRPC request validation and path rewriting
 * 
 * This function:
 * 1. Validates that requests have a Bearer token in the Authorization header
 * 2. Removes the /trpc prefix from the URI so Lambda receives the correct path
 */
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    
    // Check for Authorization header with Bearer token
    var authHeader = headers.authorization || headers.Authorization;
    
    if (!authHeader || !authHeader.value || !authHeader.value.startsWith('Bearer ')) {
        return {
            statusCode: 401,
            statusDescription: 'Unauthorized',
            headers: {
                'www-authenticate': { value: 'Bearer' }
            }
        };
    }
    
    // Remove /trpc prefix from the URI
    // /trpc/user.query -> /user.query
    request.uri = request.uri.replace(/^\/trpc/, '');
    
    // Ensure URI starts with /
    if (!request.uri.startsWith('/')) {
        request.uri = '/' + request.uri;
    }
    
    return request;
}