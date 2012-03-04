/*
 * MCURLConnection.j
 * MCResource
 *
 * Created by Joachim Garth
 * Copyright 2011, Monkey & Company UG (haftungsbeschränkt)
 *
 * This class is a subclass of CPURLConnection, in order to customize its behavior
 * and gain access to facilities such as progress events
 *
 */

@implementation MCURLConnection : CPURLConnection
{
	
}

// We override this method in order to send FormData objects, because of 
// their smaller memory footprint when sending files,
// as well as gaining more access to event listeners on XMLHTTPRequest
- (void)start
{
    _isCanceled = NO;

    try
    {
		if([_delegate respondsToSelector:@selector(connection:progressDidChange:)])
		{
			var progressFunction = function(event) 
			{
				if (event.lengthComputable) 
				{
					var percentage = event.loaded / event.total;
					[_delegate connection:self progressDidChange:percentage];
				}
			};
			
			_HTTPRequest._nativeRequest.addEventListener("progress", progressFunction, false);			
			_HTTPRequest._nativeRequest.upload.addEventListener("progress", progressFunction, false);
		}

        _HTTPRequest.open([_request HTTPMethod], [[_request URL] absoluteString], YES);

        _HTTPRequest.onreadystatechange = function() { [self _readyStateDidChange]; }

        var fields = [_request allHTTPHeaderFields],
            key = nil,
            keys = [fields keyEnumerator];

        while (key = [keys nextObject])
            _HTTPRequest.setRequestHeader(key, [fields objectForKey:key]);

		if([_request respondsToSelector:@selector(formData)] && [_request formData])
		{
        	_HTTPRequest.send([_request formData]);			
		}
		else
		{
			_HTTPRequest.send([_request HTTPBody]);
		}

    }
    catch (anException)
    {
        if ([_delegate respondsToSelector:@selector(connection:didFailWithError:)])
            [_delegate connection:self didFailWithError:anException];
    }
}

@end