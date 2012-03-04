var MCGlobalQueueObject = nil;

@implementation MCQueue : CPObject
{
	CPArray 		_queuedRequests;
	CPArray			_processedRequests;
	BOOL 			_isRunning;
	MCQueuedRequest	_currentRequest;
	var				_queueRunningCheckFunction;
}

// Returns global queue object
+ (MCQueue)sharedQueue
{
	if(!MCGlobalQueueObject)
	{
		MCGlobalQueueObject = [[MCQueue alloc] init];
	}
	
	return MCGlobalQueueObject;
}

- (id)init
{
	if(self = [super init])
	{
		_queuedRequests = [];
		_processedRequests = [];
	}
	
	return self;
}

#pragma mark -
#pragma mark Queue manipulation

// Append a new request to the queue
- (void)appendRequest:(MCQueuedRequest)request
{
	if(!request)
	    return;

	// Attach it
	[_queuedRequests addObject:request];
	
	// If the queue was not stopped, process it immediately
	if(_isRunning)
	{
		[self processQueue];
	}
}

// Append new requests to the queue
- (void)appendRequests:(CPArray)requests
{
	if(!requests)
	    return;

	// Attach it
	[_queuedRequests addObjectsFromArray:requests];
	
	// If the queue was not stopped, process it immediately
	if(_isRunning)
	{
		[self processQueue];
	}
}

- (CPArray)queue
{
	return _queuedRequests;
}

- (MCQueuedRequest)currentRequest
{
	return _currentRequest;
}

#pragma mark -
#pragma mark Queue state control
- (void)start
{
	_isRunning = YES;
	[self processQueue];
}

- (void)stop
{
	_isRunning = NO;
}

- (BOOL)isRunning
{
	return _isRunning;
}

#pragma mark -
#pragma mark Internal methods

- (void)processQueue
{
	// While the queue is full and running
	while([_queuedRequests count] > 0 && _isRunning)
	{
		_currentRequest = [_queuedRequests objectAtIndex:0];

		// Fire the next queued request
        CPLog.debug("Starting request: " + _currentRequest);
		[_currentRequest start];
		
		// And get it off the heap, archive it
		[_queuedRequests removeObject:_currentRequest];
		[_processedRequests addObject:_currentRequest];
	}
}

@end