var ContinuousParseTime = 100;
var LoopDelay = 20;
var sliceSize = 15;

@implementation CPArrayController (MCResourceAdditions)

- (void)addObjectsInBatches:(CPArray)objects withDelegate:(id)didLoadDelegate progressSelector:(SEL)progressSelector didFinishSelector:(SEL)didFinishSelector
{
	[self _addObjectsInBatches:objects currentIndex:0 withDelegate:didLoadDelegate progressSelector:progressSelector didFinishSelector:didFinishSelector];
}

- (void)_addObjectsInBatches:(CPArray)objects currentIndex:(int)currentIndex withDelegate:(id)didLoadDelegate progressSelector:(SEL)progressSelector didFinishSelector:(SEL)didFinishSelector
{
	var startTime = new Date().getTime(),
		objectCount = [objects count];
	
	// Parse for x ms
	while(new Date().getTime() - startTime < ContinuousParseTime && currentIndex < objectCount)
	{
	    var actualSliceSize = MIN(sliceSize, objectCount - currentIndex);
		[self addObjects:[objects subarrayWithRange:CPMakeRange(currentIndex, actualSliceSize)]];
		currentIndex += actualSliceSize;
	}
	
    // Notify the delegate about the progress
    if(didLoadDelegate && progressSelector)
        [didLoadDelegate performSelector:progressSelector];
	
	if(currentIndex < objectCount)
	{
	    // Schedule another loop
		window.setTimeout(function() {
			[self _addObjectsInBatches:objects currentIndex:currentIndex withDelegate:didLoadDelegate progressSelector:progressSelector didFinishSelector:didFinishSelector];
		}, LoopDelay)
	}
	else if(currentIndex == objectCount)
	{
	    // Or perform the didFinishSelector
	    if(didLoadDelegate && didFinishSelector)
	        [didLoadDelegate performSelector:didFinishSelector];
	}
}

/*!
    Sets the sort descriptors for the controller.

    @param CPArray descriptors - the new sort descriptors.
*/
- (void)setSortDescriptors:(CPArray)value
{
    if (_sortDescriptors === value)
        return;

    _sortDescriptors = [value copy];
    
    // Only rearrange if this controller is set to automaticallyRearrangeObjects
    if(_automaticallyRearrangesObjects)
    {
        // Use the non-notification version since arrangedObjects already depends
        // on sortDescriptors.
        [self _rearrangeObjects];        
    }
}

/*
    Like setFilterPredicate but don't fire any change notifications.
    @ignore
*/
- (void)__setFilterPredicate:(CPPredicate)value
{
    if (_filterPredicate === value)
        return;

    _filterPredicate = value;

    // Only rearrange if this controller is set to automaticallyRearrangeObjects
    if(_automaticallyRearrangesObjects)
    {
        // Use the non-notification version since arrangedObjects already depends
        // on filterPredicate.
        [self _rearrangeObjects];
    }
}


@end