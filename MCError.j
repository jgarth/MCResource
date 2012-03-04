@implementation MCError : CPObject
{
	CPString 	description @accessors;
}

+ (MCError)errorWithDescription:(CPString)aDescription
{
	var anError = [MCError new];
	[anError setDescription:aDescription];
	
	return anError;
}

@end