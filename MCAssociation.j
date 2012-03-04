@implementation MCAssociation : CPObject
{
	MCResource  _parent;
	Class		_associatedObjectClass;
	CPString 	_associationName;
	BOOL        _autosaves                  @accessors(setter=setAutosaves:,getter=autosaves);
	BOOL        _nestedOnly                 @accessors(setter=setNestedOnly:,getter=isNestedOnly);
	BOOL        _shallow                    @accessors(setter=setIsShallow:,getter=isShallow);
}

- (id)initWithName:(CPString)aName class:(Class)aClass parent:(MCResource)aParent
{
	if(self = [super init])
	{
		_associationName = aName;
		_associatedObjectClass = aClass;
		_parent = aParent;
		_autosaves = NO;
		_nestedOnly = NO;
		_shallow = NO;
	}

	return self;
}

- (CPString)description
{
	return "<" + class_getName(isa) + " 0x" + [CPString stringWithHash:[self UID]] + ": " + _associationName + " on " + [_parent className] + ">";
}

@end