MCUpperCaseRegExp = new RegExp('([ABCDEFGHIJKLMNOPQRSTUVWXYZ])', 'g');
MCUnderscoreRegExp = new RegExp('^_');
MCCappifyStringRegExp = new RegExp(/_([a-z])/g);
MCCappifyStringFunction = function () { return arguments[0][1].toUpperCase(); };

@implementation CPString (MCResourceAdditions)

// Transform strings to a lowercased and underscored representation
- (CPString)railsifiedString
{
    var subStrings = self.split('::');

    for(var i = 0; i < subStrings.length; i++)
      subStrings[i] = subStrings[i].replace(MCUpperCaseRegExp,'_$1').replace(MCUnderscoreRegExp,'');
    
    return subStrings.join('/').toLowerCase();
}

// Transform strings to camel-cased representation
- (CPString)cappifiedString
{
	return self.replace(MCCappifyStringRegExp, MCCappifyStringFunction);
}

// Cappified class names (like cappified strings, but starting with an uppercase letter)
- (CPString)cappifiedClass
{
	var string = [self cappifiedString];
	
	// Capitalize first letter
	string = string.charAt(0).toUpperCase() + string.substring(1, string.length);

	return string;
}

// Singularize a string
- (CPString)singularize
{
	var string = self;
	
	if(self.substring(self.length - 3, self.length) == 'ies')
	{
		// "Properties" -> "Property"
		string = string.substring(0, string.length - 3) + 'y';
	}
	else
	{
		// "Variants" -> "Variant"
		string = string.substring(0, string.length - 1);		
	}
	
	return string;
}

// Pluralize a string
- (CPString)pluralize
{
	var string = self;
	
	if(self.substring(self.length - 1, self.length) != 's')
	{
		if(self.substring(self.length -1, self.length) == 'y')
		{
			string = self.substring(0, self.length - 1) + "ies";
		}
		else
		{
			string += "s";
		}
	}
	
	return string;
}

// Create an URL-level parameter string from a CPDictionary
+ (CPString)parameterStringFromDictionary:(CPDictionary)params
{
    var paramsArray = [CPArray array],
        keys        = [params allKeys];

    for (var i = 0; i < [params count]; ++i) {
        var aKey = keys[i];
        var aValue = [params valueForKey:aKey];
        
        if(aKey.toString().match(/[~\!\*\(\)']/) || aValue.toString().match(/[~\!\*\(\)']/))
        {
            CPLog.warn(@"Invalid characters in parameter set: \"%@ = %@\". The following characters are not allowed: ~!*()'", aKey, aValue);
            continue;
        }
        
        [paramsArray addObject:(encodeURIComponent(aKey) + "=" + encodeURIComponent(aValue))];
    }

    return "?" + paramsArray.join("&");
}

@end