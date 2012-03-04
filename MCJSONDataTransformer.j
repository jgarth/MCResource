/*
 * MCJSONDataTransformer.j
 * MCResource
 *
 * Created by Joachim Garth
 * Copyright 2011, Monkey & Company UG (haftungsbeschränkt)
 *
 * This class is an example implementation of a CPDictionary -> FormData and JSON -> CPDictionary transformer.
 * Nothing more, nothing less.
 *
 */

@implementation MCJSONDataTransformer : CPObject

// Transforms a CPDictionary into a FormData object
- (JSObject)transformedData:(id)data
{
	_formData = new FormData();

	if(!data)
	{
		return nil;
	}

	[self _fillFormData:_formData withData:data prefix:nil];

	return _formData;
}

// Transform a JSON-String to a CPDictionary / CPArray
- (CPDictionary)reverseTransformedData:(CPString)data
{
	if([data length] > 0 && ![data isEqualToString:@" "])
	{
		try 
		{
			var parsedObject = JSON.parse(data);
			
			if (parsedObject) 
			{
				if(parsedObject.isa && [parsedObject isKindOfClass:[CPArray class]])
				{
					var returnArray = [CPArray new],
						enumerator = [parsedObject objectEnumerator],
						item;
				
					while(item = [enumerator nextObject])
					{
						[returnArray addObject:[CPDictionary dictionaryWithJSObject:item recursively:YES]];
					}
					
					return returnArray;
				}
				else
				{
		        	return [CPDictionary dictionaryWithJSObject:parsedObject recursively:YES];					
				}
		    }
		}
		catch (anyException) 
		{
		    throw [MCError errorWithDescription:@"Could not reverse transform the following data: '" + data + "'"];
		}
	}
}

#pragma mark -
#pragma mark Internal Methods

/*
 * This method recursively iterates through a CPDictionary and 
 * saves all its values in a passed-in FormData object
 */ 
 
- (void)_fillFormData:(JSObject)aFormData withData:(CPDictionary)data prefix:(CPString)prefix
{
	var keyEnumerator = [data keyEnumerator],
		currentKey;
		
	while(currentKey = [keyEnumerator nextObject])
	{
		var currentValue = [data valueForKey:currentKey];
		
		if(currentValue.isa && [currentValue isKindOfClass:[CPDate class]])
		{
		    currentValue = [currentValue ISO8601String];
		}
		
		if(currentValue.isa && [currentValue isKindOfClass:[CPNull class]])
		{
		    currentValue = null;
		}

		// Recurse if neccessary
		if(currentValue && currentValue.isa && [currentValue isKindOfClass:[CPDictionary class]])
		{
			// This must get triggered on the first loop
			if(!prefix)
			{
				prefix = currentKey;
				[self _fillFormData:aFormData withData:currentValue prefix:prefix];
			}
			else
			{
				[self _fillFormData:aFormData withData:currentValue prefix:prefix + "[" + currentKey + "]"];	
			}
		}
		else
		{
			aFormData.append(prefix + "[" + currentKey + "]", currentValue);
		}
	}
}

@end