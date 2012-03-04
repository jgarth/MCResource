@implementation CPArray (MCResourceAdditions)

- (CPArray)objectsCommonWithArray:(CPArray)otherArray
{
    var i = 0;
    var output = [];
    
    for(; i < [self count]; i++)
    {
        var object = [self objectAtIndex:i];
        
        if([otherArray containsObject:object])
        {
            [output addObject:object];
        }
    }
    
    if([output count] > 0)
        return output;
    else
        return nil;
}

@end