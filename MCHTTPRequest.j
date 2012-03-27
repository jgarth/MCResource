/*
 * MCHTTPRequest.j
 * MCResource
 *
 * Created by Joachim Garth
 * Copyright 2011, Monkey & Company UG (haftungsbeschränkt)
 *
 * This class represents an atomic request to one URL via HTTP.
 *
 */

/*
 * The delegate must implement the following methods:
 * - (void)requestDidFinish:(MCHTTPRequest)aRequest
 * - (void)requestDidFail:(MCHTTPRequest)aRequest
 *
 * You can use the status, error and responseData properties for further processing.
 *
 * An example request can be constructed like so:
 *
 * // Setup some example data to be transferred
 * var testDict = { "order": {
 * 		"number": 123456789,
 *  	"customer_id": 1,
 *  	"payment_means": {
 *  	 	"name": "WireTransfer",
 *  		"id": 2
 *  	},
 *  	"id": 3
 *  } };
 * 
 * // Construct a request
 * var saveRequest = [MCHTTPRequest requestTarget:[CPURL URLWithString:@"/orders/123"]
 *  									withMethod:@"PUT"
 *    								   andDelegate:self];
 * 
 * // Convert our test values to a CPDictionary
 * var testCPDict = [CPDictionary dictionaryWithJSObject:testDict recursively:YES];
 *  
 * // Set data to be transmitted 
 * [saveRequest setData:testCPDict];
 * 
 * // And finally, start the request
 * [saveRequest start];
 *
 */
 
// File-scoped variables -- class variables
var MCHTTPRequestDelegate = nil;
var MCHTTPRequestDelegateRespondsToAuthorizationCredentials = NO;
var MCHTTPRequestCachedDefaultTransformer = [MCJSONDataTransformer new];

@implementation MCHTTPRequest : CPObject
{
	// Public variables
	CPURL		URL							@accessors;
	CPString	HTTPMethod					@accessors;
	CPString    HTTPBody                    @accessors;
	CPString	authorizationCredentials	@accessors;
	id			dataTransformer				@accessors;
	MCError		error						@accessors(readonly);
	id			responseData				@accessors(readonly);
	id			delegate					@accessors;

	// Internal variables
	CPString			_data;
	MCURLConnection		_connection;
	CPHTTPURLResponse	_response;
	CPDictionary		_HTTPHeaderFields;
	CPData				_responseData;
	JSObject			_formData;
}

#pragma mark -
#pragma mark Class methods

// Set the class delegate
+ (void)setDelegate:(id)aDelegate
{
	MCHTTPRequestDelegate = aDelegate;
	
	if([aDelegate respondsToSelector:@selector(authorizationCredentials)])
	{
		MCHTTPRequestDelegateRespondsToAuthorizationCredentials = YES;
	}
	else
	{
		MCHTTPRequestDelegateRespondsToAuthorizationCredentials = NO;
	}
}

// Get the class delegate
+ (id)delegate
{
	return MCHTTPRequestDelegate;
}

#pragma mark -
#pragma mark Initializers

// Designated Constructor
+ (MCHTTPRequest)requestTarget:(CPURL)aTarget withMethod:(CPString)aMethod andDelegate:(id)aDelegate
{
	var aRequest = [self new];
	[aRequest setDelegate:aDelegate];
	[aRequest setURL:aTarget];
	[aRequest setHTTPMethod:aMethod];
	
	return aRequest;
}

// Default initializer
- (id)init
{
	if(self = [super init])
	{
		// Set default values
		dataTransformer = MCHTTPRequestCachedDefaultTransformer;
		HTTPMethod = @"GET";
		
		// Set default headers
		_HTTPHeaderFields = [CPDictionary dictionary];

		// Add appropriate fields to request to indicate the sending of, and preferred response with JSON data
		[_HTTPHeaderFields setValue:@"application/json" forKey:@"Accept"];
		// Use this in case we switch back to sending JSON
		// [_HTTPHeaderFields setValue:@"application/json" forKey:@"Content-Type"];

		// Try to bypass any undue caching (proxies, etc.)
	    [_HTTPHeaderFields setValue:"Thu, 01 Jan 1970 00:00:00 GMT" forKey:"If-Modified-Since"];
	    [_HTTPHeaderFields setValue:"no-cache" forKey:"Cache-Control"];
	    [_HTTPHeaderFields setValue:"XMLHttpRequest" forKey:"X-Requested-With"];

		// Add authorization credentials if 
		// a) they were specified through setAuthorizationCredentials: 
		// b) none were specified but the class delegate can supply them.
		if(authorizationCredentials)
		{
			[_HTTPHeaderFields setValue:authorizationCredentials forKey:@"Authorization"];
		}
		else if(MCHTTPRequestDelegateRespondsToAuthorizationCredentials)
		{
			[_HTTPHeaderFields setValue:[[[self class] delegate] authorizationCredentials] forKey:@"Authorization"];		
		}
	}
		
	return self;
}

#pragma mark -
#pragma mark Custom Accessors

/* Expects a CPDictionary with a single root node
 *
 *	ex. { "image": {
 *			"name": "Some Name",
 *			"size": 423098,
 *			"file": [object File] }
 *		}
 *
 *	Supports File objects in the dictionary. These will be uploaded.
 */

- (void)setData:(CPDictionary)someData
{
	// Conserve memory
	delete _formData;
	
	// Build new formData
	_formData = [dataTransformer transformedData:someData];
}

// Set a single key-value pair
- (void)setData:(id)value forKey:(CPString)aKey
{
    if(!_formData)
        _formData = new FormData();
	
	_formData.append(aKey, value);
}

// Returns the FormData object containing the data to be sent.
- (JSObject)formData
{
	return _formData;
}

// Set the request's HTTP body directly, set formData to nil
- (void)setRawData:(CPString)rawData
{
    HTTPBody = rawData;
    _formData = nil;
}

// Returns the dictionary containing all set HTTP headers and their values
- (JSObject)allHTTPHeaderFields
{
	return _HTTPHeaderFields;
}

// Set the HTTP verb to be used as a method.
// Only valid arguments are: 'PUT', 'POST', 'GET', 'DELETE'.
// The method is not case-sensitive.
//
- (void)setHTTPMethod:(CPString)aMethod
{
	if(HTTPMethod === aMethod)
		return;
		
	// Make sure the given method is valid
	if(!aMethod || !aMethod.match(/(put|get|delete|post)/i))
	{
		throw [MCError errorWithDescription:@"Unknown HTTP request method: '" + aMethod + "'"]; 
	}
	
	HTTPMethod = aMethod;
}

// Set any HTTP header directly
- (void)setValue:(id)aValue forHTTPHeader:(CPString)aHeader
{
    [_HTTPHeaderFields setValue:aValue forKey:aHeader];
}

// Return the internal connection's status
// as returned by MCURLConnection
//
- (int)status
{
	return [_connection status];
}

// Return the last response's status code
- (int)responseStatus
{
    if(_response)
        return [_response statusCode];
    else
        return CPNotFound;
}

// Start the connection
// Returns YES if the connection has been started
// Returns NO if the connection could not be started
//
- (BOOL)start
{
	if(_connection)
	{
		CPLog.warn("Connection has already started");
		return YES;
	}
	
	error = nil;
	_connection = [[MCURLConnection alloc] initWithRequest:self delegate:self startImmediately:YES];
	
	if(_connection)
		return YES;
	else
		return NO;
}

// Cancel the connection
// Returns YES if the connection has been canceled
// Returns NO if the connection could not be canceled
//
- (BOOL)cancel
{
	return [_connection cancel];
}

#pragma mark -
#pragma mark Useful overrides

- (CPString)description
{
	return @"<MCHTTPRequest " + [self HTTPMethod] + " to " + [self URL] + ">";
}

#pragma mark -
#pragma mark NSURLConnection delegate methods

/*
 * CPURLConnection delegate methods (used by MCURLConnection as well) 
 * For documentation of these methods, see Cappuccino docs
 */ 
- (void)connection:(CPURLConnection)aConnection didFailWithError:(id)anError
{
	if(delegate)
	{
		error = anError;
		[delegate requestDidFail:self];		
	}
	else
	{
		throw [MCError errorWithDescription:"Request failed with error: " + error];
	}
}

- (void)connection:(CPURLConnection)aConnection didReceiveResponse:(CPHTTPURLResponse)aResponse
{
	_response = aResponse;
	
	if(![aResponse isKindOfClass:[CPHTTPURLResponse class]])
	{
		CPLog.warn("Expected a CPHTTPURLResponse, but got '" + [aResponse class] + "' instead. Status codes are probably not reliable.");
	}
}

- (void)connection:(CPURLConnection)connection didReceiveData:(CPString)data
{
	// Basically, all we do here is appending, all day long
	_responseData = (_responseData || @"") + data;
}

- (void)connectionDidFinishLoading:(CPURLConnection)connection
{
	// The request either succeeded (or there's no info about success, e.g. a local file connection)
	if(![_response isKindOfClass:[CPHTTPURLResponse class]] || [_response statusCode] >= 200 && [_response statusCode] <= 300)
	{
		if(_responseData)
		{
			// If we can, transform the data back to something useful
			if(dataTransformer)
				responseData = [dataTransformer reverseTransformedData:_responseData];
			else
				responseData = _responseData;
		}
		
		[[CPNotificationCenter defaultCenter] postNotificationName:MCHTTPRequestDidFinishNotificationName
		 													object:self];
		
		if(delegate)
		{
			[delegate requestDidFinish:self];
		}
	}
	else // or it failed
	{
		if([_response isKindOfClass:[CPHTTPURLResponse class]])
		{
			error = [MCError errorWithDescription:@"Request failed with status " + [_response statusCode]];
			if([_response statusCode] == 422 && _responseData && dataTransformer)
		    {
        		// If we can, transform the data back to something useful
        		responseData = [dataTransformer reverseTransformedData:_responseData];
			}
		}

		[delegate requestDidFail:self];
	}
}

- (void)connection:(CPURLConnection)connection progressDidChange:(float)progress
{
	[[CPNotificationCenter defaultCenter] postNotificationName:MCHTTPRequestDidChangeProgressNotificationName
	 													object:self 
													  userInfo:[CPDictionary dictionaryWithObject:progress forKey:@"progress"]];
}

// If we reach this callback, then authentication has already failed
- (void)connectionDidReceiveAuthenticationChallenge:(CPURLConnection)aConnection
{
	throw [MCError errorWithDescription:@"Access denied to " + URL + " by server with 401 Forbidden"];
}

@end