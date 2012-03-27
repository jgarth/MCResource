@import "Constants.j"
@import "MCError.j"
@import "MCJSONDataTransformer.j"
@import "MCURLConnection.j"
@import "MCHTTPRequest.j"
@import "MCQueuedRequest.j"
@import "MCQueue.j"
@import "MCAssociation.j"
@import "MCHasOneAssociation.j"
@import "MCHasManyAssociation.j"
@import "MCBelongsToAssociation.j"
@import "CPString-MCResourceAdditions.j"
@import "CPDate-MCResourceAdditions.j"
@import "CPArrayController-MCResourceAdditions.j"
@import "CPArray-MCResourceAdditions.j"
@import "MCValidation.j"

MCResourceServerURLPrefix = @"";

// Options dictionary key names
MCResourceAssociationClassKey           = @"MCResourceAssociationClassKey";
MCResourceAssociationObjectClassKey     = @"MCResourceAssociationObjectClassKey";
MCResourceAssociationAutosaveKey        = @"MCResourceAssociationAutosaveKey";
MCResourceAssociationShallowKey         = @"MCResourceAssociationShallowKey";
MCResourceAssociationNestedOnlyKey      = @"MCResourceAssociationNestedOnlyKey";
MCResourceAssociationSortDescriptorsKey = @"MCResourceAssociationSortDescriptorsKey";

// These are all file-scoped
var classAttributesDictionary = [CPDictionary dictionary];
var classMethodDelegateDictionary = [CPDictionary dictionary];
var classMethodSelectorDictionary = [CPDictionary dictionary];
var classAssociationsDictionary = [CPDictionary dictionary];
var classValidationsDictionary = [CPDictionary dictionary];
var classUniqueAttributesDictionary = [CPDictionary dictionary];

var _MCResourceErrorAlertIsShowing = NO;

var AllResourcesByTypeAndId = [CPDictionary dictionary];


/*
 *	MCResource
 * 
 *  This is where the magic happens. Syntax and methods are strongly inspired by ActiveRecord, part of Ruby on Rails, (c) 37signals
 *	The most notable difference is, this class does not support synchronous requesting, so EVERY request must be made with separate
 *  requesting and processing parts. It will usually work with a delegate callback.
 *
 */

@implementation MCResource : CPObject
{
	// Common attributes that every record has
	CPDate			createdAt;
	CPDate			updatedAt;

	// Internal attributes - all of these MUST begin with an underscore to avoid conflicts with model attribute names!
	CPDictionary	_changes;
	CPDictionary    _changesForRemote;
	CPString		_identifier;
	CPDictionary	_associations;
	CPDictionary    _errors;
	
	MCAssociation   _reflection;
	
	CPDictionary	_instanceMethodDelegateDictionary;
	CPDictionary	_instanceMethodSelectorDictionary;
	
	CPURL           _resourceURL;
	
	BOOL            _isReloading;
}

#pragma mark -
#pragma mark Setup methods (Behavior)

// Override this to make this resource behave like a singleton
+ (BOOL)isSingletonResource
{
	return NO;
}

// Override this to set a custom identifier field. Default is "id"
+ (CPString)identifierKey
{
	return "id";
}

// Override this to set a custom wrapping name for saving / loading
+ (CPString)railsName
{
    return [[self className] railsifiedString];
}

// Mark unique attributes with this method
// This will affect saving behavior
+ (void)hasUniqueAttribute:(CPString)attributeName
{
    var uniqueAttributes = [classUniqueAttributesDictionary objectForKey:[self className]];
    
    if(!uniqueAttributes)
    {
        [classUniqueAttributesDictionary setObject:[attributeName] forKey:[self className]];
    }
    else
    {
        [uniqueAttributes addObject:attributeName];
    }
}

+ (CPArray)uniqueAttributes
{
    return [classUniqueAttributesDictionary objectForKey:[self className]];
}

#pragma mark -
#pragma mark Setup methods (Associations)

+ (void)hasOne:(CPString)aName
{
	[self addAssociationWithName:aName class:MCHasOneAssociation options:[CPDictionary dictionary]];
}

+ (void)hasOne:(CPString)aName options:(CPDictionary)options
{
	[self addAssociationWithName:aName class:MCHasOneAssociation options:options];
}

+ (void)hasMany:(CPString)aName
{
	[self addAssociationWithName:aName class:MCHasManyAssociation options:[CPDictionary dictionary]];
}

+ (void)hasMany:(CPString)aName options:(CPDictionary)options
{
	[self addAssociationWithName:aName class:MCHasManyAssociation options:options];
}

+ (void)belongsTo:(CPString)aName
{
    [self addAssociationWithName:aName class:MCBelongsToAssociation options:[CPDictionary dictionary]];
}

+ (void)belongsTo:(CPString)aName options:(CPDictionary)options
{
    [self addAssociationWithName:aName class:MCBelongsToAssociation options:options];
}

+ (void)addAssociationWithName:(CPString)aName class:(Class)associationClass options:(CPDictionary)options
{
    var associatedObjectClass, autosave, shallow, isNestedOnly, sortDescriptors;
    
    if(!options || !(associatedObjectClass = [options objectForKey:MCResourceAssociationObjectClassKey]))
    {
        if(associationClass === MCHasManyAssociation)
            associatedObjectClass = objj_getClass([[aName singularize] cappifiedClass]);
        else
            associatedObjectClass = objj_getClass([aName cappifiedClass]);
    }
    
    if(!options || !(sortDescriptors = [options objectForKey:MCResourceAssociationSortDescriptorsKey]))
    {
        sortDescriptors = [];
    }
    
    if(!associatedObjectClass)
	{
	    CPLog.error(@"Could not find class '" + [aName cappifiedClass] + "' for association in object " + [self className]);
	}
    
    if(!options || !(autosave = [options objectForKey:MCResourceAssociationAutosaveKey]))
    {
        autosave = NO;
    }
    
    if(!options || !(shallow = [options objectForKey:MCResourceAssociationShallowKey]))
    {
        shallow = NO;
    }
    
    if(!options || !(isNestedOnly = [options objectForKey:MCResourceAssociationNestedOnlyKey]))
    {
        isNestedOnly = NO;
    }
        
	// Add the association to the class ivars
	// Just as if you had typed "MCHas(One|Many)Association <name>" in the class declaration
	class_addIvar(self, aName, [associationClass className]);

	// Remember this association's options
	if(![classAssociationsDictionary objectForKey:[self className]])
	{
		[classAssociationsDictionary setObject:[CPDictionary dictionary] forKey:[self className]];
	}
	
	var optionsDictionary = [CPDictionary dictionaryWithObjects:[associationClass, 
	                                                             associatedObjectClass, 
	                                                             autosave, 
	                                                             shallow, 
	                                                             isNestedOnly, 
	                                                             sortDescriptors]
	                                                    forKeys:[MCResourceAssociationClassKey, 
	                                                             MCResourceAssociationObjectClassKey,
	                                                             MCResourceAssociationAutosaveKey, 
	                                                             MCResourceAssociationShallowKey, 
	                                                             MCResourceAssociationNestedOnlyKey, 
	                                                             MCResourceAssociationSortDescriptorsKey]];
	
	[[classAssociationsDictionary objectForKey:[self className]] setObject:optionsDictionary forKey:aName];
}

#pragma mark -
#pragma mark Overrides

- (id)copy
{
    var copy = [[[self class] alloc] init];
    [copy setAttributes:[self attributes]];
    
    // Strip identifier from the copy
    [copy _setValue:nil forKey:@"identifier"];
    
    return copy;
}

- (id)clone
{
    // FIXME: Copy attributes by copying ivars one by one
    var aClass = [self class];
    var clone = [[aClass alloc] init];
    var attributeNames = [[[clone class] attributes] allKeys];
        
    while([aClass superclass])
	{
	    // clone ivars
        var ivarList = class_copyIvarList(aClass);
        var ivarCount = [ivarList count];
    
        while(ivarCount--)
        {
            var ivarName = [ivarList objectAtIndex:ivarCount].name;
            clone[ivarName] = self[ivarName];
        }
    
        aClass = [aClass superclass];
    }

    // Set attribute changes
    var attributes = [[[self class] attributes] allKeys],
        attributeCount = [attributes count];
        
    while(attributeCount--)
    {
        [[clone changes] setValue:@"" forKey:[attributes objectAtIndex:attributeCount]];
    }

    [clone commit];
    
    return clone;
}

// Default & designated initializer
- (id)init
{
	if(self = [super init])
	{
		// Initialize instance variables
		_instanceMethodSelectorDictionary = [CPDictionary dictionary];
		_instanceMethodDelegateDictionary = [CPDictionary dictionary];
		_identifier = "";
		_changes = [CPDictionary dictionary];
		_changesForRemote = [CPDictionary dictionary];
		_associations = [CPDictionary dictionary];
		_errors = [CPDictionary dictionary];

		// Setup associations		
		var associationNames = [[classAssociationsDictionary objectForKey:[self className]] allKeys];

		for(var i = 0; i < [associationNames count]; i++)
		{
			var associationName = [associationNames objectAtIndex:i];
			var associationOptions = [[classAssociationsDictionary objectForKey:[self className]] objectForKey:associationName];
			var	associationTypeClass = [associationOptions objectForKey:MCResourceAssociationClassKey];
			var	associationClass = [associationOptions objectForKey:MCResourceAssociationObjectClassKey];
			var	association = [[associationTypeClass alloc] initWithName:associationName class:associationClass parent:self];
			var autosaves = [associationOptions objectForKey:MCResourceAssociationAutosaveKey];
			var shallow = [associationOptions objectForKey:MCResourceAssociationShallowKey];
			var nestedOnly = [associationOptions objectForKey:MCResourceAssociationNestedOnlyKey];
			var sortDescriptors = [associationOptions objectForKey:MCResourceAssociationSortDescriptorsKey];

            [association setAutosaves:autosaves];
            [association setIsShallow:shallow];
            [association setNestedOnly:nestedOnly];

            if(associationTypeClass == MCHasManyAssociation && [sortDescriptors count] > 0)
            {
                [association setSortDescriptors:sortDescriptors];
            }

			[_associations setObject:association forKey:associationName];
			[self _setValue:association forKey:associationName];
			
            // Add a method to get the association
            class_addMethod(self.isa, sel_getUid(associationName), function(self, _cmd)
            {
                return self[_cmd];
            },["id"]);
            
            // FIXME: Add a proxy method to set the association
            // class_addMethod(self.isa, sel_getUid("set" + associationName + ":"), function(self, _cmd, anObject)
            // {
            //     if([association isKindOfClass:[MCHasManyAssociation class]])
            //     {
            //         console.log("NOT SUPPORTED YET set(HasManyAssociation):");
            //     }
            //     else
            //     {
            //         [association setAssociatedObject:anObject];                    
            //     }
            // },["", "id"]);
		}		
	}
	
	return self;
}

// This is a standard override for development purposes - if log output gets too messy, remove it.
- (CPString)description
{
	var description = [self className] + ", ID " + [self identifier] + ": { \n",
		attributes = [[[self class] attributes] keyEnumerator],
		attribute;
	
	while(attribute = [attributes nextObject])
	{
		description += "\t " + attribute + " = '" + [self valueForKey:attribute] + "'\n";
	}
	
	description += "};";
	
	return description;
}

#pragma mark -
#pragma mark Public methods

- (MCAssociation)associationForName:(CPString)aName
{
    return [_associations objectForKey:aName];
}

+ (MCResource)getResourceWithId:(int)anIdentifier ofClass:(Class)resourceClass
{
    return [AllResourcesByTypeAndId valueForKeyPath:resourceClass + "." + anIdentifier];
}

+ (CPArray)allResourcesOfClass:(Class)resourceClass
{
    return [AllResourcesByTypeAndId valueForKey:resourceClass]
}

// Find associated records under the URL of the parent record
+ (void)findAsAssociated:(CPDictionary)params withDelegate:(id)aDelegate andSelector:(SEL)aSelector parent:(MCResource)parent 
{
    resourceURL = [parent resourceURL] + '/' + [self _constructResourceURL];
    [self find:params withDelegate:aDelegate andSelector:aSelector resourceURL:resourceURL];    
}

// Find a record on the server with the given params
+ (void)find:(CPDictionary)params withDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    [self find:params withDelegate:aDelegate andSelector:aSelector resourceURL:[self resourceURL]];
}

+ (void)find:(CPDictionary)params withDelegate:(id)aDelegate andSelector:(SEL)aSelector resourceURL:(CPURL)resourceURL
{
	// Add the passed-in parameters to our request
	if(params)
	{
		resourceURL += [CPString parameterStringFromDictionary:params];
	}
	
    // Construct a request
	var target = [CPURL URLWithString:resourceURL],
		request = [MCHTTPRequest requestTarget:target withMethod:@"GET" andDelegate:self],
		queuedRequest = [MCQueuedRequest queuedRequestWithRequest:request];
	
	// Register the callback in our file-scoped callback dictionary
	[classMethodDelegateDictionary setObject:aDelegate forKey:queuedRequest];
	[classMethodSelectorDictionary setObject:aSelector forKey:queuedRequest];
	
	// Append the wrapped request to the queue
	[[MCQueue sharedQueue] appendRequest:queuedRequest];
}

// Save a resource on the server. Automatically saves associations along with the resource.
- (MCQueuedRequest)saveWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    return [self saveWithDelegate:aDelegate andSelector:aSelector startImmediately:YES];
}

- (MCQueuedRequest)saveWithDelegate:(id)aDelegate andSelector:(SEL)aSelector startImmediately:(BOOL)startImmediately
{
    // Commit uncommitted changed
    [self commit];
    
    // Build a save request
	var masterRequest = [self _buildSaveRequest];
	
	// If there's nothing to save, consider it a success and call the delegate's selector
	if(!masterRequest)
	{
	    if(aDelegate && aSelector && startImmediately)
	        [aDelegate performSelector:aSelector withObject:self];
	        
	    return nil;
	}

	// Register the callback in our instance's callback dictionary
	[_instanceMethodDelegateDictionary setObject:aDelegate forKey:masterRequest];
	[_instanceMethodSelectorDictionary setObject:aSelector forKey:masterRequest];
	
	// Append the wrapped request to the queue if appropriate
	if(startImmediately)
	    [[MCQueue sharedQueue] appendRequest:masterRequest];
	
	return masterRequest;
}

// Reload a resource's data via RESTful 'show' action
- (void)reloadWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
	// Construct the reload request
	var request = [self _buildReloadRequest];
	
	// Register a didReload: callback
	[_instanceMethodDelegateDictionary setObject:aDelegate forKey:request];
	[_instanceMethodSelectorDictionary setObject:aSelector forKey:request];
	
	_isReloading = YES;
	
	// Append the wrapped request to the queue
	[[MCQueue sharedQueue] appendRequest:request];
}

// Delete a resource via RESTful 'delete' action
- (MCQueuedRequest)deleteWithDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
    return [self deleteWithDelegate:aDelegate andSelector:aSelector startImmediately:YES];
}

- (MCQueuedRequest)deleteWithDelegate:(id)aDelegate andSelector:(SEL)aSelector startImmediately:(BOOL)startImmediately
{
	// Construct the delete request
	var target = [CPURL URLWithString:[self resourceURL]],
		request = [MCHTTPRequest requestTarget:target withMethod:@"DELETE" andDelegate:self],
		queuedRequest = [MCQueuedRequest queuedRequestWithRequest:request];
		
	// Register a didReload: callback
	[_instanceMethodDelegateDictionary setObject:aDelegate forKey:queuedRequest];
	[_instanceMethodSelectorDictionary setObject:aSelector forKey:queuedRequest];
	
	// Append the wrapped request to the queue if appropriate
	if(startImmediately)
	    [[MCQueue sharedQueue] appendRequest:queuedRequest];
	    
	return queuedRequest;
}

- (BOOL)isNewRecord
{
    return !_identifier;
}

- (CPString)identifier
{
	return _identifier;
}

- (void)setIdentifier:(int)identifier
{
    if(_identifier && identifier != _identifier)
    {
        CPLog.warn(@"Re-set identifier on %@", self);
        return;
    }
    
    if(isNaN(identifier))
    {
        [CPException raise:CPInvalidArgumentException reason:@"Identifier must be a number but was " + identifier + " (" + typeof identifier + ")" + " (Object: " + self + ")"];
        return;
    }
    
	_identifier = identifier;
	
	// Take care of registering the product in our global AllResourcesByTypeAndId dictionary
	var resourcesByType = [AllResourcesByTypeAndId objectForKey:[self className]];

	if(!resourcesByType)
	{
	    [AllResourcesByTypeAndId setObject:[CPDictionary dictionaryWithObject:self forKey:_identifier] forKey:[self className]];
	}
	else
	{
	    [resourcesByType setObject:self forKey:_identifier];
	}
}

// Returns a dictionary containing all the resource's attributes
- (CPDictionary)attributes
{
	var returnedDictionary = [CPDictionary dictionary],
		associations = [[classAssociationsDictionary objectForKey:[self className]] allKeys],
		attributeNames = [[[self class] attributes] allKeys],
		attributeEnumerator = [attributeNames objectEnumerator],
		attribute;

	// Run through all attributes
	while(attribute = [attributeEnumerator nextObject])
	{
		// Obviously, we don't want to include associations here
		if([associations containsObject:attribute])
		{
			continue;
		}
		
		[returnedDictionary setObject:[self valueForKey:attribute] forKey:[attribute railsifiedString]];
	}
	
	// Wrap the attributes under another root dictionary with the class name
	var wrappedDictionary = [CPDictionary dictionaryWithObject:returnedDictionary forKey:[[self className] railsifiedString]];
	
	return wrappedDictionary;
}

#pragma mark -
#pragma mark Change management

// Returns the raw change dictionary
- (CPDictionary)changesForRemote
{
    return _changesForRemote;
}

- (BOOL)hasChangesForServer
{
    return ([_changesForRemote count] > 0);
}

- (void)commit
{
    [_changesForRemote addEntriesFromDictionary:_changes];
    [_changes removeAllObjects];
}

- (CPDictionary)changes
{
    return _changes;
}

- (BOOL)hasChanges
{
    return ([_changes count] > 0);
}

// Reverts all recorded changes
- (void)revert
{
    var changedKeys = [_changes keyEnumerator],
        changedKey;
        
    while(changedKey = [changedKeys nextObject])
    {
        [self _setValue:[_changes objectForKey:changedKey] forKey:changedKey];
    }
    
    [_changes removeAllObjects];
}

// Returns a dictionary containing only changed attributes
- (CPDictionary)attributesForSave
{
    var returnedDictionary = [CPDictionary dictionary],
        changedKeys = [_changesForRemote keyEnumerator],
        changedKey;
    
    while(changedKey = [changedKeys nextObject])
    {
        var changedValue = [self valueForKey:changedKey];
        
        // Set empty values correctly
        if((!changedValue && !(changedValue === NO) && !(changedValue === 0)) || changedValue === "")
        {
            changedValue = [CPNull null];
        }
        
        if(changedValue.isa && ![changedValue isKindOfClass:[MCResource class]])
        {
            // Set compound values correctly (convert them to dictionaries)
            if([changedValue respondsToSelector:@selector(attributes)])
            {
                changedValue = [changedValue attributes];                
            }
        }
        
        [returnedDictionary setObject:changedValue forKey:[changedKey railsifiedString]];
    }
    
    // Don't return a dictionary if there's nothing to save    
    if([[returnedDictionary allKeys] count] === 0)
    {
        return nil;
    }
    
    // Wrap the attributes under another root dictionary with the class name
	var wrappedDictionary = [CPDictionary dictionaryWithObject:returnedDictionary forKey:[[self class] railsName]];
	
	return wrappedDictionary;
}

// Uses a dictionary to set the resource's attributes
- (void)setAttributes:(JSObject)attributeDictionary
{
	var givenAttributes = [attributeDictionary objectForKey:[[self class] railsName]],
		classAttributes = [[self class] attributes];

	var identifierKey = [[self class] identifierKey],
		identifier = [givenAttributes objectForKey:identifierKey];

	// Special treatment for the resource identifier key
	if(identifier && ![identifier isKindOfClass:[CPNull class]])
	{
		[self setIdentifier:identifier];
		[givenAttributes removeObjectForKey:identifierKey];
	}
	else
	{
		// CPLog.warn(@"Resource " + self + " loaded without identifier key! This will likely cause problems in the future.");
	}

	// And normal treatment for the other keys
	var	attributeEnumerator = [givenAttributes keyEnumerator],
		attribute;

	while(attribute = [attributeEnumerator nextObject])
	{
		var attributeName = [attribute cappifiedString],
		    attributeType = [classAttributes objectForKey:attributeName];

		var	aValue = [givenAttributes valueForKey:attribute];

		if(attributeType)
		{
			switch(attributeType)
			{
			    case "CPArray":
                    [self _setValue:aValue forKey:attributeName];
			        break;
				case "CPString":
					// Set null values as null values, not string representations of CPNull
					if(!([aValue isKindOfClass:[CPNull class]] || (typeof aValue == 'String' && aValue.length == 0)))
					{
						[self _setValue:aValue forKey:attributeName];
					}
					break;
				case "CPDate":
				    if([aValue isKindOfClass:[CPDate class]])
				    {
				        [self _setValue:aValue forKey:attributeName];
				    }
				    else
				    {
					    [self _setValue:[CPDate dateWithDateTimeString:aValue] forKey:attributeName];				        
				    }
					break;
				case "CPNumber":
				    var parsedValue = parseFloat(aValue);
				    if(!isNaN(parsedValue))
				    {
					    [self _setValue:parsedValue forKey:attributeName];				        
				    }
					break;
				case "BOOL":
				    [self _setValue:!!aValue forKey:attributeName];
				    break;
				default:
				    var childClassAssociation = [[classAssociationsDictionary objectForKey:[self className]] objectForKey:attributeName];

					if(childClassAssociation)
					{
					    var childClass = [childClassAssociation objectForKey:MCResourceAssociationObjectClassKey],
					        childClassAssociationType = [childClassAssociation objectForKey:MCResourceAssociationClassKey];

				        if(childClassAssociationType == MCHasManyAssociation)
					    {
                            // Parse the array
                            var theHasManyAssociation = [_associations objectForKey:attributeName],
                                childObjectDataEnumerator = [aValue objectEnumerator],
                                childObjectData;
                            
                            while(childObjectData = [childObjectDataEnumerator nextObject])
                            {
                                var childObj = [childClass new];
                                [childObj setAttributes:[CPDictionary dictionaryWithObject:childObjectData forKey:[[childClass className] railsifiedString]]];
                                [theHasManyAssociation addAssociatedObject:childObj];
                                [childObj resourceDidLoad];
                            }
					    }
					    else
					    {
							var childObj = [childClass new];
							[childObj setAttributes:[CPDictionary dictionaryWithObject:aValue forKey:[[childClass className] railsifiedString]]];	
							
							// Send out KVO-notifications for association object changes
							[self willChangeValueForKey:attributeName];
							[[_associations objectForKey:attributeName] setAssociatedObject:childObj];
							[self didChangeValueForKey:attributeName];
                            [childObj resourceDidLoad];
					    }

					}
					else if((childClass = objj_getClass(attributeType)) || (childClass = objj_getClass([attributeName cappifiedClass])))
					{
						var childObj = [childClass new];
						
						if([aValue isKindOfClass:[CPDictionary class]])
						{
							var childAttributeEnumerator = [aValue keyEnumerator],
								childAttributeName;
								
							// FIXME: Refactor in the future to get ivar class-based parsing for child objects	
							while(childAttributeName = [childAttributeEnumerator nextObject])
							{
							    var value = [aValue objectForKey:childAttributeName],
            				        parsedValue = parseFloat(value);

            				    if(!isNaN(parsedValue))
            				    {
            				        value = [CPNumber numberWithFloat:parsedValue];            				        
            				    }
							    
								[childObj setValue:value forKey:[childAttributeName cappifiedString]];
							}
							
							// Use the KVO-notifying version of setValue:forKey: here to
							// enable binding to child objects even if they are not
							// associations.
							[self willChangeValueForKey:attributeName];
							[self _setValue:childObj forKey:attributeName];
							[self didChangeValueForKey:attributeName];
						}
						else if(aValue === nil || [aValue isKindOfClass:[CPNull class]])
						{
						    // Do nothing
						}
						else
						{
						    console.log("Class: " + aValue + " " + [aValue className]);
							CPLog.warn(@"Don't know how to parse objects of class " + [attributeName cappifiedClass] + ". Only dictionary parsing into custom objects is supported.");
						}
					}
					else
					{
						CPLog.warn(@"Unknown type for attribute " + [attributeName cappifiedClass] + " in class " + [self class] + " (could not find class named " + [attributeName cappifiedClass] + " or " + attributeType + ")");						
					}
					break;
			}
		}
		else
		{
		//	CPLog.warn("Could not parse attribute: " + attributeName + " into class " + [self class]);
		}
	}
}

- (BOOL)isReloading
{
    return _isReloading;
}

#pragma mark -
#pragma mark Hooks

// Override in child classes. Will be executed right after resource was fetched from server with its attributes already set.
- (void)resourceDidLoad
{
    
}

#pragma mark -
#pragma mark Resource validation

+ (void)validate:(CPString)field with:(MCValidation)aValidation
{
    var classValidations = [classValidationsDictionary objectForKey:[self className]];
    
    if(!classValidations)
    {
        [classValidationsDictionary setObject:[CPDictionary dictionary] forKey:[self className]];
    }
    
    var fieldValidations = [classValidations objectForKey:field];
    
    if(!fieldValidations)
    {
        [[classValidationsDictionary objectForKey:[self className]] setObject:[aValidation] forKey:field];        
    }
    else
    {
        [fieldValidations addObject:aValidation];
    }
}

- (BOOL)valid
{
    var classValidations = [classValidationsDictionary objectForKey:[self className]];
    var _hasError = NO;
    
    if(!classValidations)
        return YES;
        
    [_errors removeAllObjects];
    
    var validatedFieldEnumerator = [classValidations keyEnumerator],
        validatedField;

    while(validatedField = [validatedFieldEnumerator nextObject])
    {
        var validations = [classValidations objectForKey:validatedField],
            validationEnumerator = [validations objectEnumerator],
            validation;
            
        while(validation = [validationEnumerator nextObject])
        {
//            console.log("Checking: " + validatedField + " value: " + [[self valueForKeyPath:validatedField] description]);
            var error = [validation errorForValue:[self valueForKeyPath:validatedField]];
            
            if(error)
            {
                _hasError = YES;
                
                if(![_errors objectForKey:validatedField])
                {
                    [_errors setObject:[CPArray array] forKey:validatedField];
                }

                [[_errors objectForKey:validatedField] addObject:error];                    
            }
        }
    }
    
    if(!_hasError)
    {
        [_errors removeAllObjects];
    }
    
    // console.log("Checked " + [self objjDescription] + " - errors: " + [_errors description]);
    
    return !_hasError;
}

- (CPDictionary)errors
{
    return _errors;
}

- (BOOL)hasErrors
{
    return (_errors && [_errors count] > 0);
}

- (CPString)humanReadableErrors
{
    // Generate a simple list
    var errors = [self errors];

    if(!errors || [errors count] == 0)
    {
        return @"";
    }
    
    var errorKeyEnumerator = [errors keyEnumerator],
        errorKey,
        errorString = @"";
        
    while(errorKey = [errorKeyEnumerator nextObject])
    {
        errorString += [CPString stringWithFormat:@"• %@ %@\n", errorKey, [errors objectForKey:errorKey]];
    }
    
    return errorString;
}

#pragma mark -
#pragma mark Internal methods

- (CPString)objjDescription
{
    return [self description];
}

- (MCQueuedRequest)_buildReloadRequest
{
    // Construct master reload request
    var target = [CPURL URLWithString:[self resourceURL]],
		request = [MCHTTPRequest requestTarget:target withMethod:@"GET" andDelegate:self],
		queuedRequest = [MCQueuedRequest queuedRequestWithRequest:request];
	
	// Construct association reload requests
	var associationNames = [_associations keyEnumerator],
	    associationName;
	    
	while(associationName = [associationNames nextObject])
	{
	    var association = [_associations objectForKey:associationName],
		    associationOptions = [[classAssociationsDictionary objectForKey:[self className]] objectForKey:associationName];
		    
		// Skip associations that cannot be loaded seperately
		if([associationOptions valueForKey:MCResourceAssociationNestedOnlyKey] === YES)
		{
		    continue;
		}
		
	    var subRequest = [association _buildLoadRequest];
	        
	    if(subRequest)
	        [queuedRequest addChildRequest:subRequest];
	}
		
    return queuedRequest;
}

// Constructs a queable request intended to push the resource class to the server
- (MCQueuedRequest)_buildSaveRequest
{
    return [self _buildSaveRequestWithURL:[self resourceURL]];
}

- (MCQueuedRequest)_buildSaveRequestWithURL:(CPURL)saveURL
{
	// Construct a request
	var target = [CPURL URLWithString:saveURL],
	 	request = [MCHTTPRequest requestTarget:target withMethod:[self _methodForSaving] andDelegate:self];

	// Pass in the model's data for saving
	var savedAttributes = [self attributesForSave];
	
	// Don't need to save when nothing has changed and the record previously existed
	if([self identifier] && !savedAttributes)
	    return nil;

	[request setData:savedAttributes];
	
	var queuedRequest = [MCQueuedRequest queuedRequestWithRequest:request];
	
	// Append association save requests
	var associationEnumerator = [_associations objectEnumerator],
		association;
		
	while(association = [associationEnumerator nextObject])
	{
	    if([association autosaves])
	    {
	        if([association isKindOfClass:[MCHasOneAssociation class]])
	        {
        		var associationSaveRequest = [association _buildSaveRequest];
        		[queuedRequest addChildRequest:associationSaveRequest];	            
	        }
            else
            {
                var associationSaveRequests = [association _buildSaveRequests];
                [queuedRequest addChildRequests:associationSaveRequests];
            }
	    }
	}
	
	// Return a queuedRequest with sub-requests for associations
	return queuedRequest;
}

// Determines HTTP method for saving - new resources should be sent with POST, existing resources with PUT
- (CPString)_methodForSaving
{
	if([self identifier])
	{
		return @"PUT";
	}
	else
	{
		return @"POST";
	}
}

// This method is used if you want to change a value, but not track the change (e.g. mass updates)
- (void)_setValue:(id)someValue forKey:(CPString)key
{
	[super setValue:someValue forKey:key];
}

// This method will not only set a value, but also register the change internally
- (void)setValue:(id)someValue forKey:(CPString)key
{
    var oldValue = [self valueForKey:key];
    
	// Remember the PREVIOUS value if it's an attribute
	if(![_changes objectForKey:key] && ((!oldValue && someValue) || (oldValue && oldValue !== someValue && ![oldValue isEqual:someValue])) && [[[self class] attributes] containsKey:key])
    {
        if(oldValue === nil)
	        oldValue = [CPNull null];

		[_changes setObject:oldValue forKey:key];
	}
	
	// and set the new value
	[super setValue:someValue forKey:key];
}

- (void)setValue:(id)someValue forKeyPath:(CPString)keyPath
{
    // If the keyPath lies within this object,
    // pass it to setValue:forKey: to track changes
    if(keyPath.split('.').length < 2)
    {
        [self setValue:someValue forKey:keyPath];
    }
    else
    {
        // FIXME
        // Until CPFormatter support is properly integrated, we need to catch these here and
        // add them to our change dictionary
        // Suppose we bind a CPPopUpButton to: object.price.taxRate – without a formatter, 
        // there's no way to manipulate the entire object and set it back here
        
        // Still, this is far from a perfect solution
        var keys = keyPath.split('.'),
            ourKey = keys[0],
            childKeyPath = keys.slice(1),
            childObject = [self valueForKey:ourKey];

        // Remember the PREVIOUS value
    	if(![_changes objectForKey:ourKey] && [[[self class] attributes] containsKey:ourKey])
        {
         	[_changes setObject:[childObject copy] forKey:ourKey];
    	}

        [super setValue:someValue forKeyPath:keyPath];
    }
}

// FIXME: Maybe think about a grand replacement using -forwardInvocation:
// Because the Objective-J method "doesNotRecognizeSelector:", unlike Ruby's method_missing?,
// is not able to provide a return value, valueForKeyPath will directly forward to an association's
// associated object(s) - to get the actual association object, you need to use the instance variable
- (id)valueForKey:(id)aKey
{
    var association = [_associations objectForKey:aKey];

    if(association)
    {
        if([association isKindOfClass:[MCHasManyAssociation class]])
        {
            return [association associatedObjects];
        }
        else
        {
            return [association associatedObject];
        }
    }
    else
    {
        return [super valueForKey:aKey];
    }
}

#pragma mark -
#pragma mark Resource URL construction

+ (CPString)resourceURL
{
	return MCResourceServerURLPrefix + "/" + [self _constructResourceURL];
}

- (void)setResourceURL:(CPString)anURL
{
    _resourceURL = anURL;
}

- (CPString)resourceURL
{
    if(_resourceURL)
    {
       return _resourceURL; 
    }

    // If we're part of an association, try to build resource URL according to that
    var prefix = "";

	if(_reflection)
	{
	    prefix = [_reflection _buildAssociationURLPrefix];
	}
	else
	{
	    prefix = MCResourceServerURLPrefix + "/";
	}
	
	_resourceURL = prefix + [self _constructResourceURL];
		
	return _resourceURL;
}

+ (CPString)_constructResourceURL
{
    var resourceName;
	
	if(![[self class] isSingletonResource])
	{
		resourceName = [[[self className] pluralize] railsifiedString];
	}
	else
	{
		resourceName = [[self className] railsifiedString];	
	}
	
	return resourceName; 
}

- (CPString)_constructResourceURL
{
	var URL = [[self class] _constructResourceURL];
    
    if(![[self class] isSingletonResource] && _identifier)
    {
	    URL += "/" + _identifier;
    }
        
    return URL;
}

// This returns a dictionary of class ivars and their types, including inherited ivars
+ (CPDictionary)attributes
{
	// Get cached values if possible
	if([classAttributesDictionary objectForKey:[self className]])
	{
		return [classAttributesDictionary objectForKey:[self className]];
	}
	
	var aClass		= [self class],
		attributes 	= [CPDictionary dictionary];
			
	// Account for MCResource class inheritance
	while([aClass isKindOfClass:[MCResource class]] || [[aClass superclass] isKindOfClass:[MCResource class]])
	{
		var classAttributes = class_copyIvarList(aClass);

		for(var i = 0; i < [classAttributes count]; i++)
		{
			var attribute = [classAttributes objectAtIndex:i];
		
			// Skip internal attributes (everything starting with an underscore)
			if(attribute.name.match('^_'))
			{
				continue;				
			}
			
			[attributes setObject:attribute.type forKey:attribute.name];
		}
	
		aClass = [aClass superclass];
	}
	
	[classAttributesDictionary setObject:attributes forKey:[self className]];

	return attributes;
}

#pragma mark -
#pragma mark Creating/Parsing Resources

+ (MCResource)_buildResourceFromAttributes:(CPDictionary)attributes
{
	var builtResource = [[self class] new];
	[builtResource setAttributes:attributes];

	return builtResource;
}

// Parses objects from an array of attribute dictionaries into an output array.
// Pauses parsing every 100ms for 20ms to increase application responsiveness
+ (void)_parseObjectsFromArray:(CPArray)input intoArray:(CPArray)output withRequest:(MCQueuedRequest)aRequest
{
    var delegate = [classMethodDelegateDictionary objectForKey:aRequest],
		selector = [classMethodSelectorDictionary objectForKey:aRequest];
	
	[self _parseObjectsFromArray:input intoArray:output withDelegate:delegate andSelector:selector];
}

+ (void)_parseObjectsFromArray:(CPArray)input intoArray:(CPArray)output withDelegate:(id)aDelegate andSelector:(SEL)aSelector
{
	var startTime = new Date().getTime();
		
	for(var i = [output count]; i < [input count]; i++)
	{
		var childObj = [self _buildResourceFromAttributes:[input objectAtIndex:i]];
		[childObj resourceDidLoad];
		[output addObject:childObj];
		
		// Every 100 ms
		if((new Date().getTime() - startTime) > 100)
		{
			if([output count] < [input count])
			{
				// Break and then resume execution after 20ms
				window.setTimeout(function() {
					[self _parseObjectsFromArray:input intoArray:output withDelegate:aDelegate andSelector:aSelector];
				}, 20);
			}
			break;
		}
	}

	if([output count] === [input count])
	{
		[aDelegate performSelector:aSelector withObject:output];
	}
}

#pragma mark -
#pragma mark Callback handling & MCHTTPRequest delegate methods

// This will be called on after executing class methods like +find
+ (void)requestDidFinish:(MCQueuedRequest)aRequest
{
	var delegate = [classMethodDelegateDictionary objectForKey:aRequest],
		selector = [classMethodSelectorDictionary objectForKey:aRequest];

	// Benchmarking
	var startTime = new Date().getTime();
	var responseData = [[aRequest HTTPRequest] responseData];
	
	// Check if we have been given one or multiple objects and act accordingly
	if([responseData isKindOfClass:[CPArray class]])
	{
		//console.profile();

		// Parse all objects, but pause for 20ms every 100 objects or so, to increase
		// application responsivenes
		[self _parseObjectsFromArray:responseData intoArray:[] withRequest:aRequest];

		//console.profileEnd();
//		CPLog.info(@"Parsed " + [requestPayload count] + "x " + [self className] + " in " + (new Date().getTime() - startTime) + " ms.")
	}
	else
	{
		var requestPayload = [self _buildResourceFromAttributes:[[aRequest HTTPRequest] responseData]];
		[requestPayload resourceDidLoad];
//		CPLog.info(@"Parsed 1x " + [self className] + " in " + (new Date().getTime() - startTime) + " ms.");
		[delegate performSelector:selector withObject:requestPayload];
	}
}

// This will be called on after executing instance methods like -reload or -save
- (void)requestDidFinish:(MCQueuedRequest)aRequest
{
	var delegate = [_instanceMethodDelegateDictionary objectForKey:aRequest],
		selector = [_instanceMethodSelectorDictionary objectForKey:aRequest],
		requestMethod = [[aRequest HTTPRequest] HTTPMethod],
		delegateObject;
		
	_isReloading = NO;
	
	// Determine whether it was a save/reload request or a delete request
	switch(requestMethod)
	{
		case "POST":
		case "PUT":
		    if([[aRequest HTTPRequest] responseStatus] == 200 || [[aRequest HTTPRequest] responseStatus] == 201)
		    {
		        // Remove changes
		        [_changesForRemote removeAllObjects];

		        // Remove errors
		        [_errors removeAllObjects];
		    }
        case "GET":
			// Incorporate the received data into this resource
			[self setAttributes:[[aRequest HTTPRequest] responseData]];
			delegateObject = self;
            
            // Expand the resource's URL if appropriate
			if(requestMethod == "POST" && [self identifier] && _resourceURL && ![[self class] isSingletonResource])
			{
			    _resourceURL = _resourceURL + '/' + [self identifier];
			}
			break;
		case "DELETE":
			delegateObject = self;
			break;
		default:
			CPLog.error(@"Received request with unknown HTTP method: " + [[aRequest HTTPRequest] HTTPMethod]);
			break;
	};

    [self resourceDidLoad];

	if(delegate && selector)
	{
		[delegate performSelector:selector withObject:delegateObject];
	}
}

+ (void)requestDidFail:(MCQueuedRequest)aRequest
{
	var aDelegate = [classMethodDelegateDictionary objectForKey:aRequest],
		aSelector = [classMethodSelectorDictionary objectForKey:aRequest];

 	var responseStatus = [[aRequest HTTPRequest] responseStatus];

    if(responseStatus === 500 || responseStatus === 400 || responseStatus === 0)
    {
	    CPLog.error(@"MCResource+requestDidFail: " + [aRequest description] + ": " + [[aRequest HTTPRequest] error]);
        [self showMCResourceErrorAlert];
    }
    else if(responseStatus === 422 || responseStatus === 404 || responseStatus == 403)
    {
        if(aDelegate && aSelector)
    	{
		    [aDelegate performSelector:aSelector withObject:nil];
    	}
    }	
}

// Let's hope this doesn't get called to often ;)
- (void)requestDidFail:(MCQueuedRequest)aRequest
{
	var aDelegate = [_instanceMethodDelegateDictionary objectForKey:aRequest],
		aSelector = [_instanceMethodSelectorDictionary objectForKey:aRequest];

 	var responseStatus = [[aRequest HTTPRequest] responseStatus];

    if(responseStatus === 500 || responseStatus === 400 || responseStatus === 0)
    {
        [[self class] showMCResourceErrorAlert];
    }
    else if(responseStatus === 422 || responseStatus === 404 || responseStatus == 403)
    {
        if(aDelegate && aSelector)
    	{
    	    // Parse errors
    	    _errors = [[aRequest HTTPRequest] responseData];
    		[aDelegate performSelector:aSelector withObject:self];
    	}
    }
        
	CPLog.debug(@"MCResource-requestDidFail: " + [aRequest description] + ": " + [[aRequest HTTPRequest] error]);
}

+ (void)showMCResourceErrorAlert
{
    if(!_MCResourceErrorAlertIsShowing)
    {
        var alert = [CPAlert alertWithMessageText:MCResourceGeneralErrorMessage
                                    defaultButton:@"Okay"
                                  alternateButton:nil
                                      otherButton:nil
                        informativeTextWithFormat:MCResourceGeneralErrorDetailedMessage];

        [alert setDelegate:self];
        [alert runModal];

        _MCResourceErrorAlertIsShowing = YES;            
    }
}

+ (void)alertDidEnd:(CPAlert)theAlert returnCode:(int)returnCode
{
    _MCResourceErrorAlertIsShowing = NO;
}

#pragma mark -
#pragma mark Utility class methods
+ (CPString)encodeCredentials:(CPString)username password:(CPString)password
{
	return @"Basic " + CFData.encodeBase64String([CPString stringWithString:username + ":" +  password]);
}

+ (CPString)decodeCredentials:(CPString)authorizationString
{
    var encoded = authorizationString.match(/^Basic (.*)/).pop();
	var userAndPassword = CFData.decodeBase64ToString(encoded).match(/(([^:]+):(.+))/);
	var password = userAndPassword.pop();
	var username = userAndPassword.pop();
	
	return {username: username, password: password};
}

@end