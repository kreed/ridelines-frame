/**
 * CloudFront Function for tRPC request validation and path rewriting
 * 
 * This function:
 * 1. Validates that requests have a Bearer token in the Authorization header
 * 2. Rewrites the Authorization header to auth-token (CloudFront strips Authorization)
 * 3. Removes the /trpc prefix from the URI so Lambda receives the correct path
 */
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    
    // Check for Authorization header with Bearer token (CloudFront converts to lowercase)
    var authHeader = headers.authorization;
    
    if (!authHeader || !authHeader.value || !authHeader.value.startsWith('Bearer ')) {
        return {
            statusCode: 401,
            statusDescription: 'Unauthorized',
            headers: {
                'www-authenticate': { value: 'Bearer' }
            }
        };
    }
    
    // Rewrite Authorization header to auth-token (CloudFront strips Authorization header)
    headers['auth-token'] = { value: authHeader.value };
    
    // Remove the original authorization header
    delete headers.authorization;
    
    // Remove /trpc prefix from the URI
    // /trpc/user.query -> /user.query
    request.uri = request.uri.replace(/^\/trpc/, '');
    
    // Ensure URI starts with /
    if (!request.uri.startsWith('/')) {
        request.uri = '/' + request.uri;
    }
    
    return request;
}