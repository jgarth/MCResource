@implementation MCValidation : CPObject
{
    
}

- (BOOL)errorForValue:(id)value
{
    [CPException raise:CPInvalidArgumentException reason:@"*** -validate cannot be sent to an abstract object of class " + [self className] + @": Create a concrete instance and override (CPString)errorForValue:"];
}

@end

#pragma mark -
#pragma mark MCStringValidation

// Common
MCValidationOptionAllowBlankKey = "MCValidationOptionAllowBlankKey";

// String validations
MCValidationOptionMinLengthKey = "MCValidationOptionMinLengthKey";
MCValidationOptionMaxLengthKey = "MCValidationOptionMaxLengthKey";
MCValidationOptionAllowEmptyKey = "MCValidationOptionAllowEmptyKey";

// Number validations
MCValidationOptionOnlyIntegerKey = "MCValidationOptionOnlyIntegerKey";
MCValidationOptionGreaterThanKey = "MCValidationOptionGreaterThanKey";
MCValidationOptionMaxKey = "MCValidationOptionMaxKey";

@implementation MCStringValidation : MCValidation
{
    int minLength       @accessors;
    int maxLength       @accessors;
    BOOL allowBlank     @accessors;
    BOOL allowEmpty     @accessors;
}

+ (MCStringValidation)stringValidationWithOptions:(CPDictionary)options
{
    var aStringValidation = [self new];
    
    if(!options)
    {
        options = [CPDictionary dictionary];
    }
    
    if([options containsKey:MCValidationOptionMinLengthKey])
        [aStringValidation setMinLength:[options objectForKey:MCValidationOptionMinLengthKey]];
        
    if([options containsKey:MCValidationOptionMaxLengthKey])
        [aStringValidation setMaxLength:[options objectForKey:MCValidationOptionMaxLengthKey]];

    if([options containsKey:MCValidationOptionAllowBlankKey])
        [aStringValidation setAllowBlank:([options objectForKey:MCValidationOptionAllowBlankKey])];
    else
        [aStringValidation setAllowBlank:YES];
        
    if([options containsKey:MCValidationOptionAllowEmptyKey])
        [aStringValidation setAllowEmpty:([options objectForKey:MCValidationOptionAllowEmptyKey])];
    else
        [aStringValidation setAllowEmpty:YES];
    
    return aStringValidation;
}

- (CPString)errorForValue:(CPString)string
{
    if(!allowBlank && (!string || (string && [string isKindOfClass:[CPString class]] && string.trim() == "")))
        return MCValidationRequiredFieldErrorMessage;
        
    if(!allowEmpty && [string isKindOfClass:[CPString class]] && string.trim() == "")
        return MCValidationRequiredFieldErrorMessage;
        
    if(minLength && string && string.length < minLength)
        return MCValidationMinLengthErrorMessage(minLength);
        
    if(maxLength && string && string.length > maxLength)
        return MCValidationMaxLengthErrorMessage(maxLength);
        
    return nil;
}

+ (MCStringValidation)notEmptyValidation
{
    return [MCStringValidation stringValidationWithOptions:[CPDictionary dictionaryWithObjects:[NO, NO] forKeys:[MCValidationOptionAllowBlankKey, MCValidationOptionAllowEmptyKey]]];
}

@end

#pragma mark -
#pragma mark MCNumberValidation

@implementation MCNumberValidation : MCValidation
{
    BOOL allowBlank     @accessors;
    BOOL onlyInteger    @accessors;
    CPNumber greaterThan @accessors;
    CPNumber max         @accessors;
}

+ (MCNumberValidation)numberValidationWithOptions:(CPDictionary)options
{
    var aNumberValidation = [self new];
    
    if(!options)
    {
        options = [CPDictionary dictionary];
    }

    if([options containsKey:MCValidationOptionAllowBlankKey])
        [aNumberValidation setAllowBlank:([options objectForKey:MCValidationOptionAllowBlankKey])];
    else
        [aNumberValidation setAllowBlank:YES];
        
    if([options containsKey:MCValidationOptionGreaterThanKey])
        [aNumberValidation setGreaterThan:[options objectForKey:MCValidationOptionGreaterThanKey]];
    
    if([options containsKey:MCValidationOptionMaxKey])
        [aNumberValidation setMax:[options objectForKey:MCValidationOptionMaxKey]];

    if([options containsKey:MCValidationOptionOnlyIntegerKey])
        [aNumberValidation setOnlyInteger:[options objectForKey:MCValidationOptionOnlyIntegerKey]];
            
    return aNumberValidation;
}

- (CPString)errorForValue:(CPNumber)number
{
    var floatValue = [number floatValue];
    
    if(!allowBlank && (floatValue === nil || floatValue === undefined || isNaN(floatValue)))
        return MCValidationRequiredFieldErrorMessage;
        
    if(greaterThan != undefined && floatValue && floatValue <= greaterThan)
        return MCValidationGreaterThanErrorMessage(greaterThan);
        
    if(max && floatValue > max)
        return MCValidationMaxValueErrorMessage(max);
        
    if(onlyInteger && floatValue !== Math.round(floatValue))
        return MCValidationOnlyIntegerErrorMessage;

    return nil;
}

@end

#pragma mark -
#pragma mark MCAssociationValidation

MCValidationOptionMinChildrenKey = "MCValidationOptionMinChildrenKey";
MCValidationOptionMaxChildrenKey = "MCValidationOptionMaxChildrenKey";
MCValidationOptionValidatesChildrenKey = "MCValidationOptionValidatesChildrenKey";

@implementation MCAssociationValidation : MCValidation
{
    int         minChildren       @accessors;
    int         maxChildren       @accessors;
    BOOL        validatesChildren @accessors;
}

+ (MCStringValidation)associationValidationWithOptions:(CPDictionary)options
{
    var anAssociationValidation = [self new];
    
    if(!options)
    {
        options = [CPDictionary dictionary];
    }
    
    [anAssociationValidation setMinChildren:[options objectForKey:MCValidationOptionMinChildrenKey]];
    [anAssociationValidation setMaxChildren:[options objectForKey:MCValidationOptionMaxChildrenKey]];
    [anAssociationValidation setValidatesChildren:[options objectForKey:MCValidationOptionValidatesChildrenKey]];
    
    return anAssociationValidation;
}

- (CPString)errorForValue:(CPArray)array
{
    if(minChildren > 0 && [array count] < minChildren)
    {
        return MCValidationMinChildrenErrorMessage;
    }
    
    if(maxChildren > 0 && [array count] > maxChildren)
    {
        return MCValidationMaxChildrenErrorMessage;
    }
    
    if(validatesChildren)
    {
        var childCount = [array count],
            childErrors = [CPDictionary dictionary];

        while(childCount--)
        {
            var child = [array objectAtIndex:childCount];
            
            if(![child valid])
            {
                [childErrors setObject:[child errors] forKey:[child UID]];
            }
        }
        
        if([childErrors count] > 0)
            return childErrors;   
    }
    
    return nil;
}

@end