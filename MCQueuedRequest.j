// This is basically a queable wrapper for MCHTTPRequest
@implementation MCQueuedRequest : CPObject
{
	MCHTTPRequest	HTTPRequest		@accessors;
	MCQueue			queue			@accessors;
	CPSet			childRequests	@accessors;
	BOOL			blocking		@accessors;
	float			progress		@accessors(readonly);
	
	CPSet           finishedChildRequests;
	id              originalDelegate;
}

// Constructor method for clean code (TM)
+ (MCQueuedRequest)queuedRequestWithRequest:(MCHTTPRequest)aRequest
{
	var queuedRequest = [[MCQueuedRequest alloc] initWithRequest:aRequest];	    
	return queuedRequest;
}

// Designated initializer
- (id)initWithRequest:(MCHTTPRequest)aRequest
{
	if(self = [super init])
	{
		childRequests = [CPSet set];
		finishedChildRequests = [CPSet set];
		[self setHTTPRequest:aRequest];
	}
	
	return self;
}

// Pass-thru methods to start/stop requests
- (void)start
{
	[HTTPRequest start];
}

- (void)cancel
{
	[HTTPRequest cancel];
}

// Wrap a request in this request
- (void)setHTTPRequest:(MCHTTPRequest)aRequest
{
	HTTPRequest = aRequest;

    // Hijack the request's delegate and register as observer
	// so we can insert all child requests into the queue upon
	// completion of the original request
	originalDelegate = [aRequest delegate];
	[aRequest setDelegate:self];
	
	[[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(requestDidChangeProgress:) name:MCHTTPRequestDidChangeProgressNotificationName object:aRequest];	
}

// Add a child request to be executed upon completion of this request.
- (void)addChildRequest:(MCQueuedRequest)childRequest
{
	[childRequests addObject:childRequest];
}

- (void)addChildRequests:(CPArray)theRequests
{
    [childRequests addObjectsFromArray:theRequests]
}

- (void)queue
{
	return [MCQueue sharedQueue];
}

#pragma mark -
#pragma mark Notification handlers

// Insert child requests if there were any
- (void)requestDidFinish:(MCQueuedRequest)aRequest
{
    // If there were no child requests, notify the original delegate immediately
    if([childRequests count] == 0)
    {
        [originalDelegate requestDidFinish:self];
    }
    else
    {
        // Otherwise, insert the child requests into the queue and register as an observer
        // to be notified upon their completion
     	var childRequest,
    	    requestEnumerator = [childRequests objectEnumerator];

    	while(childRequest = [requestEnumerator nextObject])
    	{
        	[[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(childRequestDidFinish:) name:MCHTTPRequestDidFinishNotificationName object:[childRequest HTTPRequest]];
    		[[self queue] appendRequest:childRequest];
    	}   
    }
}

- (void)childRequestDidFinish:(CPNotification)aNotification
{
    // Note that this child request did finish
    [finishedChildRequests addObject:[aNotification object]];

    // Check whether all child requests have finished
    if([childRequests count] == [finishedChildRequests count])
    {
        // and notify the original delegate
        [originalDelegate requestDidFinish:self];
    }
}

// Update the request progress
- (void)requestDidChangeProgress:(CPNotification)aNotification
{
	_progress = [[aNotification userInfo] valueForKey:@"progress"];
}

- (void)requestDidFail:(MCHTTPRequest)aRequest
{
    [originalDelegate requestDidFail:self];
}

#pragma mark -
#pragma mark Useful overrides

- (CPString)description
{
	var description = @"<MCQueuedRequest 0x" + [CPString stringWithHash:[self UID]] + ": " + [HTTPRequest HTTPMethod] + " to " + [HTTPRequest URL] + ">",
	    childRequestArray = [childRequests allObjects];
	
	for(var i = 0; i < [childRequestArray count]; i++)
	{
		description += @"\n\tChild request: " + [[childRequestArray objectAtIndex:i] description];
	}
	
	return description;
}

@end