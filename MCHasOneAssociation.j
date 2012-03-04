@implementation MCHasOneAssociation : MCAssociation
{
	MCResource 	_associatedObject;
	CPArray		_requestedKeys;
	BOOL 		_isLoadingAssociatedObject;
}

- (id)initWithName:(CPString)aName class:(Class)aClass parent:(MCResource)aParent
{
	if(self = [super initWithName:aName class:aClass parent:aParent])
	{
		_requestedKeys = [];
		_isLoadingAssociatedObject = NO;
	}
	
	return self;
}

- (void)saveWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    [_associatedObject setResourceURL:[self _buildAssociationURL]];
    [_associatedObject saveWithDelegate:aDelegate andSelector:aSelector];
}

- (CPURL)_buildAssociationURL
{
    var URL, URLBuildingObject;
    
    if(_associatedObject)
        URLBuildingObject = _associatedObject;
    else
        URLBuildingObject = _associatedObjectClass;
    
    if(_shallow)
    {
        URL = MCResourceServerURLPrefix + "/" + [URLBuildingObject _constructResourceURL];
    }
    else
    {
        URL = [_parent resourceURL] + '/' + [URLBuildingObject _constructResourceURL];
    }
    
    var hasParentalAssociationIdVariable = !!class_getInstanceVariable([_parent class], _associationName + "Id");
    
    if(hasParentalAssociationIdVariable)
    {
        var parentalAssociationId = [_parent valueForKey:_associationName + "Id"];

        if(parentalAssociationId)
        {
            URL += "/" + parentalAssociationId;            
        }
        else
        {
            if(!_associatedObject && ![_associatedObjectClass isSingletonResource])
            {
                // This happens when an associated object is no longer present
                // CPLog.error(@"Cannot load hasOne association with no object, no singleton and no parental association id.");
                return nil;
            }
        }
        
    }

//  CPLog.debug("%@ built URL on: %@ - %@, parent %@", URLBuildingObject, self, URL, _parent);
    
    return [CPURL URLWithString:URL];
}

- (MCQueuedRequest)_buildSaveRequest
{
    var associatedSaveURL = [self _buildAssociationURL];
	return [_associatedObject _buildSaveRequestWithURL:associatedSaveURL];
}

- (MCQueuedRequest)_buildLoadRequest
{
    return nil;
}

- (void)setAssociatedObject:(id)associatedObject
{
	_associatedObject = associatedObject;
	[_associatedObject setResourceURL:[self _buildAssociationURL]];
}

- (id)associatedObject
{
   	if(!_associatedObject)
	{
		// Load the association on first access
        [self loadAssociatedObjectIfNeccessary];
		return nil;
	}
 
    return _associatedObject;
}

- (void)loadAssociatedObjectIfNeccessary
{
    if(!_isLoadingAssociatedObject && ![self isNestedOnly])
	{
		_isLoadingAssociatedObject = YES;
		
		var hasParentalAssociationIdVariable = !!class_getInstanceVariable([_parent class], _associationName + "Id");

        if(hasParentalAssociationIdVariable)
        {
            var parentalAssociationId = [_parent valueForKey:_associationName + "Id"];

		    if(!parentalAssociationId && !_associatedObject && ![_associatedObjectClass isSingletonResource])
		    {
		        // Cannot load hasOne association with no object, no singleton and no parental association id.
		        CPLog.error(@"%@: Cannot load non-singleton hasOne association with no object, and no parental association id.", self);
		        return;   
		    }
        }
        else if(!_associatedObject && ![_associatedObjectClass isSingletonResource])
        {
            CPLog.error(@"%@: Unnested non-singleton hasOne association needs parental association id variable (i.e. '%@')!", self, ([_parent class], _associationName + "Id"));
            return;
        }
        
        
		[_associatedObjectClass find:nil withDelegate:self andSelector:@selector(associationDidLoad:) resourceURL:[self _buildAssociationURL]];
	}
}

// Fired when the association has acutally been loaded
- (void)associationDidLoad:(MCResource)aResource
{
	var uniqueKeys = [CPSet setWithArray:_requestedKeys],
		uniqueKeyEnumerator = [uniqueKeys objectEnumerator],
		requestedKey;
	
	// Send out KVO notifications for all keys that have been requested 
	// back when the object was not loaded yet.
	while(requestedKey = [uniqueKeyEnumerator nextObject])
	{
		[self willChangeValueForKey:requestedKey];
	}
	
	// Send out a KVO-Notification via the parent
    [_parent willChangeValueForKey:_associationName];
	_associatedObject = aResource;
	[_associatedObject setResourceURL:[self _buildAssociationURL]];
    [_parent didChangeValueForKey:_associationName];
    
	uniqueKeyEnumerator = [uniqueKeys objectEnumerator];
	while(requestedKey = [uniqueKeyEnumerator nextObject])
	{
		[self didChangeValueForKey:requestedKey];
	}

	// And post a general notification who whomever cares
	[[CPNotificationCenter defaultCenter] postNotificationName:MCAssociationDidLoadNotificationName object:self];
}

// Forward requests for unknown keys to our associated object
- (id)valueForUndefinedKey:(CPString)key
{
	if(!_associatedObject)
	{
		// If we're asked for an undefined key, and we cannot deliver it, remember which key it was for later
		[_requestedKeys addObject:key];	
		
		// And load the association
		if(!_isLoadingAssociatedObject)
		{
			_isLoadingAssociatedObject = YES;
			_associatedObject = [_associatedObjectClass find:nil withDelegate:self andSelector:@selector(associationDidLoad:) resourceURL:[self _buildAssociationURL]];
		}

		return nil;
	}
	
	return [_associatedObject valueForKey:key];
}

// FIXME: How to handle this on un-preloaded objects?
- (void)setValue:(id)aValue forUndefinedKey:(CPString)key
{
	[_associatedObject setValue:aValue forKeyPath:key];
}

@end