@implementation MCHasManyAssociation : MCAssociation
{
	CPSet   _associatedObjects;
	BOOL    _isLoadingAssociatedObjects;
	BOOL    _didLoadAssociatedObjects;
	id      _saveDelegate;
	SEL     _saveSelector;
	id      _loadDelegate;
	SEL     _loadSelector;
	int     _unsavedAssociationCount;
	CPArray _sortDescriptors @accessors(setter=setSortDescriptors:);
	CPArray _objectsToDelete;
	CPURL   _customURL @accessors(setter=setCustomURL:);

	_CPObservableArray _observableAssociatedObjectArray;
}

- (id)initWithName:(CPString)aName class:(Class)aClass parent:(MCResource)aParent
{
    if(self = [super initWithName:aName class:aClass parent:aParent])
    {
        _sortDescriptors = [];
        _associatedObjects = [CPSet new];
        _observableAssociatedObjectArray = [_CPObservableArray new];
        _objectsToDelete = [];
        _didLoadAssociatedObjects = NO;
        _isLoadingAssociatedObjects = NO;
    }

    return self;
}

- (CPString)description
{
	return [CPString stringWithFormat:@"<%@ 0x%@: \"%@\" on %@ (%d objects)>", class_getName(isa), [CPString stringWithHash:[self UID]], _associationName, [_parent className], [self count]];
}

#pragma mark -
#pragma mark Content and Array methods

- (CPSet)associatedObjectSet
{
    return _associatedObjects;
}

- (_CPObservableArray)associatedObjects
{
    [self loadAssociatedObjectsIfNeccessary];
    return _observableAssociatedObjectArray;
}

- (void)addAssociatedObjects:(CPArray)theObjects
{
    var objectEnumerator = [theObjects objectEnumerator],
        object;

    [_parent willChangeValueForKey:_associationName];

    while(object = [objectEnumerator nextObject])
    {
        [self addAssociatedObjectInBatch:object];
    }

    // Re-sort if applicable
    if(_sortDescriptors.length > 0)
    {
        [_observableAssociatedObjectArray sortUsingDescriptors:_sortDescriptors];
    }

    [_parent didChangeValueForKey:_associationName];
}

// By adding an object to this association, the following things happen:
// - reflection is set
- (void)addAssociatedObjectInBatch:(id)anObject
{
    [anObject _setValue:self forKey:@"_reflection"];

    // Clear Resource's URL, will be rebuilt
    [anObject setResourceURL:nil];

    var countBeforeInsertion = [_associatedObjects count];
    [_associatedObjects addObject:anObject];

    if([_associatedObjects count] > countBeforeInsertion)
    {
        [_observableAssociatedObjectArray addObject:anObject];
    }
}

- (void)addAssociatedObject:(id)anObject
{
    [_parent willChangeValueForKey:_associationName];

    [self addAssociatedObjectInBatch:anObject];

    // Re-sort if applicable
    if(_sortDescriptors.length > 0)
    {
        [_observableAssociatedObjectArray sortUsingDescriptors:_sortDescriptors];
    }

    [_parent didChangeValueForKey:_associationName];
}

- (void)removeAssociatedObject:(id)anObject
{
    [_parent willChangeValueForKey:_associationName];
    [_objectsToDelete addObject:anObject];
    [_associatedObjects removeObject:anObject];
    [_observableAssociatedObjectArray removeObject:anObject];
    [_parent didChangeValueForKey:_associationName];
}

- (void)removeAssociatedObjects:(CPArray)objects
{
    [_parent willChangeValueForKey:_associationName];
    [_objectsToDelete addObjectsFromArray:objects];
    [_associatedObjects removeObjectsInArray:objects];
    [_observableAssociatedObjectArray removeObjectsInArray:objects];
    [_parent didChangeValueForKey:_associationName];
}

- (id)objectAtIndex:(int)index
{
    [self loadAssociatedObjectsIfNeccessary];

    if([_observableAssociatedObjectArray count] >= index)
    {
        return [_observableAssociatedObjectArray objectAtIndex:index];
    }
    else
    {
        return nil;
    }
}

- (void)loadAssociatedObjectsWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    _loadDelegate = aDelegate;
    _loadSelector = aSelector;

   [self loadAssociatedObjects];
}

- (void)loadAssociatedObjects
{
    if(_nestedOnly)
        return;

    var loadRequest = [self _buildLoadRequest];
    _isLoadingAssociatedObjects = YES;
    [[MCQueue sharedQueue] appendRequest:loadRequest];
}

- (void)loadAssociatedObjectsIfNeccessary
{
    // Cannot load associations on unsaved objects
    if(![_parent identifier])
        return;

    if([_associatedObjects count] == 0 && !_didLoadAssociatedObjects && !_isLoadingAssociatedObjects)
    {
        [self loadAssociatedObjects];
    }
}

- (BOOL)didLoad
{
    return _didLoadAssociatedObjects;
}

- (BOOL)isLoading
{
    return _isLoadingAssociatedObjects;
}

#pragma mark -
#pragma mark Actions

- (id)build
{
    var newObject = [_associatedObjectClass new];

    return newObject;
}

- (CPArray)saveWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    return [self saveWithDelegate:aDelegate andSelector:aSelector startImmediately:YES];
}

- (CPArray)saveWithDelegate:(id)aDelegate andSelector:(SEL)aSelector startImmediately:(BOOL)startImmediately
{
    var saveRequests = [self _buildSaveRequests];

    _saveDelegate = aDelegate;
    _saveSelector = aSelector;

    if([saveRequests count] > 0 && startImmediately)
    {
        var associationSaveQueue = [MCQueue new];
        [associationSaveQueue appendRequests:saveRequests];
        [associationSaveQueue start];
    }
    else if(startImmediately && aDelegate && aSelector)
    {
        [_saveDelegate performSelector:_saveSelector withObject:self];
    }

    return saveRequests;
}

- (CPArray)removedObjects
{
    return [_objectsToDelete copy];
}

// This method will actually delete the object on the server
- (void)deleteAssociatedObject:(id)anObject
{
    if([_associatedObjects containsObject:anObject])
    {
        if([anObject isNewRecord])
        {
            [self didDeleteAssociatedObject:anObject]
        }
        else
        {
            [anObject deleteWithDelegate:self andSelector:@selector(didDeleteAssociatedObject:)];
        }
    }
    else
    {
        [CPException raise:CPInvalidArgumentException reason:@"" + [anObject description] + " is not part of " + [self description]];
    }
}

- (BOOL)hasErrors
{
    var i = 0;

    for(; i < [_associatedObjects count]; i++)
    {
        var associatedObject = [[_associatedObjects allObjects] objectAtIndex:i];
        if([associatedObject hasErrors])
            return YES;
    }

    return NO;
}

- (CPString)humanReadableErrors
{
    var allAssociatedObjectErrors = [_associatedObjects valueForKeyPath:@"humanReadableErrors"];

    if([allAssociatedObjectErrors isKindOfClass:[CPSet class]])
    {
        allAssociatedObjectErrors = [allAssociatedObjectErrors allObjects];
    }

    if(allAssociatedObjectErrors && ([allAssociatedObjectErrors isKindOfClass:[CPArray class]]))
        return allAssociatedObjectErrors.join("\n");
    else
        return @"";
}

#pragma mark -
#pragma mark Helpers

- (MCQueuedRequest)_buildLoadRequest
{
    var target = _customURL;
    
    if(!target)
        target = [CPURL URLWithString:[_parent resourceURL] + '/' + [_associatedObjectClass _constructResourceURL]];
    
    var request = [MCHTTPRequest requestTarget:target withMethod:@"GET" andDelegate:self],
	    queuedRequest = [MCQueuedRequest queuedRequestWithRequest:request];

        

    _isLoadingAssociatedObjects = YES;

    return queuedRequest;
}

- (CPArray)_buildSaveRequests
{
    var _unsavedAssociationCount = 0,
        saveRequests = [];

    // Add delete requests first
    var deletedObjectEnumerator = [_objectsToDelete objectEnumerator],
        deletedObject;

    while(deletedObject = [deletedObjectEnumerator nextObject])
    {
        if(![deletedObject isNewRecord])
        {
            [saveRequests addObject:[deletedObject deleteWithDelegate:self andSelector:@selector(associatedObjectDidSave:) startImmediately:NO]];
            _unsavedAssociationCount++;
        }
    }

    [_objectsToDelete removeAllObjects];

    var associatedObjectEnumerator = [_associatedObjects objectEnumerator],
        associatedObject;

    var uniqueAttributes = [_associatedObjectClass uniqueAttributes];

    var requeuedSaveRequests = [];

    while(associatedObject = [associatedObjectEnumerator nextObject])
    {
        [associatedObject commit];

        var attributesForSave = [associatedObject attributesForSave];

        if(attributesForSave || [associatedObject isNewRecord])
        {
            // Check for unique attributes
            var uniqueAttributesToSave = [[[associatedObject changes] allKeys] objectsCommonWithArray:uniqueAttributes];

            if(uniqueAttributesToSave && ![associatedObject isNewRecord])
            {
                var uniqueAttributesToSaveCount = [uniqueAttributesToSave count];

                var associatedObjectClone = [associatedObject clone];

                // Replace them with a temporary value before issuing the first save request
                while(uniqueAttributesToSaveCount--)
                {
                    var uniqueAttributeName = [uniqueAttributesToSave objectAtIndex:uniqueAttributesToSaveCount];
                    [associatedObjectClone setValue:MCGenerateShortRandom() forKey:uniqueAttributeName];
                }

                // Add the save request containing temporary values to the save queue
                [saveRequests addObject:[associatedObjectClone saveWithDelegate:nil andSelector:nil startImmediately:NO]];
                [requeuedSaveRequests addObject:[associatedObject saveWithDelegate:self andSelector:@selector(associatedObjectDidSave:) startImmediately:NO]];
            }
            else
            {
                var saveRequest = [associatedObject saveWithDelegate:self andSelector:@selector(associatedObjectDidSave:) startImmediately:NO];
                [saveRequests addObject:saveRequest];
            }

            _unsavedAssociationCount++;
        }
    }

    // Add any out-of-queue requests now (such as saving unique values that were replaced by temps earlier) as child requests of the last request in the "replaced" save queue
    [[saveRequests lastObject] addChildRequests:requeuedSaveRequests];

    return saveRequests;
}

- (CPURL)_buildAssociationURL
{
    return [self _buildAssociationURLWithObject:nil];
}

- (CPString)_buildAssociationURLPrefix
{
    if(_shallow)
    {
        return @"";
    }
    else
    {
        return [_parent resourceURL] + "/";
    }
}

- (CPURL)_buildAssociationURLWithObject:(id)anObject
{
    var URL,
        URLBuildingObject = (anObject ? anObject : _associatedObjectClass),
        lastURLPart = [URLBuildingObject _constructResourceURL];

    if(_shallow)
    {
        URL = MCResourceServerURLPrefix + "/" + lastURLPart;
    }
    else
    {
        URL = [_parent resourceURL] + '/' + lastURLPart;
    }

    return [CPURL URLWithString:URL];
}

#pragma mark -
#pragma mark Callbacks

- (void)didDeleteAssociatedObject:(id)anObject
{
    [_parent willChangeValueForKey:_associationName];
    [self removeAssociatedObject:anObject];
    [_parent didChangeValueForKey:_associationName];
}

// Will be called when associated objects were loaded either via -loadAssociatedObjects or
// via MCResource-setAttributes: method in case of nested objects
- (void)didLoadAssociatedObjects:(CPArray)associatedObjects
{
    _didLoadAssociatedObjects = YES;
    _isLoadingAssociatedObjects = NO;

    [_parent willChangeValueForKey:_associationName];

    // Remove all objects (except unsaved ones)
    [_associatedObjects enumerateObjectsUsingBlock:function(associatedObject) {
        if(![associatedObject isNewRecord])
        {
            [_associatedObjects removeObject:associatedObject];
            [_observableAssociatedObjectArray removeObject:associatedObject];
        }
    }];

    [self addAssociatedObjects:associatedObjects];

    [_parent didChangeValueForKey:_associationName];

    if(_loadDelegate && _loadSelector)
    {
        [_loadDelegate performSelector:_loadSelector withObject:associatedObjects];
    }
}

- (void)associatedObjectDidSave:(id)object
{
    if((--_unsavedAssociationCount) === 0)
    {
        [_saveDelegate performSelector:_saveSelector withObject:self];
    }
}

- (void)requestDidFinish:(MCQueuedRequest)aRequest
{
    [_associatedObjectClass _parseObjectsFromArray:[[aRequest HTTPRequest] responseData] intoArray:[] withDelegate:self andSelector:@selector(didLoadAssociatedObjects:)];
}

- (void)requestDidFail:(MCQueuedRequest)aRequest
{
    CPLog.error(@"%@ – request did fail: %@", self, aRequest);
}

#pragma mark -
#pragma mark Method proxying

// We forward all array methods like "-objectsAtIndexes:", "-count", etc. to our 
// observable array, so that straight-forward bindings are possible, like:
//
// [someController bind:@"content" toObject:aResource withKeyPath:@"associationName" options:nil]
//
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if(![self respondsToSelector:aSelector] && [_observableAssociatedObjectArray respondsToSelector:aSelector])
        return _observableAssociatedObjectArray;        

    return nil;
}

- (CPMethodSignature)methodSignatureForSelector:(SEL)aSelector
{
    return nil;
}

- (void)forwardInvocation:(CPInvocation)anInvocation
{
    [anInvocation invokeWithTarget:_associatedObjects];
}

@end
