var MCDateTimeRegExp = new RegExp(/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([-+])(\d{2}):(\d{2})/);

// Inspired by http://delete.me.uk/2005/03/iso8601.html
var zeropad = function (num) { return ((num < 10) ? '0' : '') + num; }


@implementation CPDate (MCResourceAdditions)

// Create a CPDate object directly from the ISO string or whatever Rails uses
+ (CPDate)dateWithDateTimeString:(CPString)aDateTime
{
	if(!aDateTime || [aDateTime isKindOfClass:[CPNull class]])
		return nil;
		
    var dateParts		= aDateTime.match(MCDateTimeRegExp),	
		date 			= new Date(dateParts[1], dateParts[2] - 1, dateParts[3], dateParts[4], dateParts[5], dateParts[6]),
        timeZoneOffset 	= (Number(dateParts[8]) * 60 + Number(dateParts[9])) * (dateParts[7] === '-' ? -1 : 1);

    self = new Date(date.getTime() + (timeZoneOffset + date.getTimezoneOffset()) * 60 * 1000);
    return self;
}

- (int)year
{
    return self.getFullYear();
}

- (CPString)twoDigitYear
{
	return self.getFullYear().toString().substring(2,4);
}

- (int)month
{
    return self.getMonth() + 1;
}

- (CPString)twoDigitMonth
{
	var month = [self month];
	return zeropad(month);
}

- (CPString)humanMonth
{
	return MCResourceMonthNames[[self month] - 1];
}

- (int)day
{
    return self.getDate();
}

- (CPString)twoDigitDay
{
	var day = self.getDate();
	return zeropad(day);
}

- (CPString)twoDigitHour
{
	var hours = self.getHours();
	return zeropad(hours);
}

- (CPString)twoDigitMinute
{
	var minutes = self.getMinutes();
	return zeropad(minutes);
}

- (CPString)shortDate
{
    return [self twoDigitDay] + "." + [self twoDigitMonth] + "." + [self twoDigitYear];
}

- (CPString)ISO8601String
{
    var isoString = self.getUTCFullYear() + "-" + 
                    zeropad(self.getUTCMonth() + 1) + "-" + 
                    zeropad(self.getUTCDate()) + "T" + 
                    zeropad(self.getUTCHours()) + ":" + zeropad(self.getUTCMinutes()) + ":" + zeropad(self.getUTCSeconds()) +
                    "Z";

    return isoString;
}

@end