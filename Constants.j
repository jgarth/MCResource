MCAssociationDidLoadNotificationName = "MCAssociationDidLoadNotification"
MCHTTPRequestDidChangeProgressNotificationName = "MCHTTPRequestDidChangeProgressNotification";
MCHTTPRequestDidFinishNotificationName = "MCHTTPRequestDidFinishNotification";

// Generates a 10-figure pseudorandom string
MCGenerateShortRandom = function() {
    return (new Date().getMilliseconds() + Math.random() * 1e6).toString().substring(10);
};

// Messages & Strings

// German
// MCValidationRequiredFieldErrorMessage = @"Bitte fülle dieses Feld aus";
// function MCValidationMinLengthErrorMessage(minLength) {return [CPString stringWithFormat:@"Bitte trage mehr als %d Zeichen ein", minLength];};
// function MCValidationMaxLengthErrorMessage(maxLength) {return [CPString stringWithFormat:@"Bitte trage weniger als %d Zeichen ein", maxLength];};
// function MCValidationGreaterThanErrorMessage(greaterThan) {return [CPString stringWithFormat:@"Bitte gib einen Wert größer als %d an", greaterThan];};
// function MCValidationMaxValueErrorMessage(maxValue) {return [CPString stringWithFormat:@"Bitte gib einen Wert kleiner als %d an", maxValue];};
// MCValidationOnlyIntegerErrorMessage = @"Bitte gib eine ganze Zahl an";
// MCValidationMinChildrenErrorMessage = @"sind zu wenige";
// MCValidationMaxChildrenErrorMessage = @"sind zu viele";
// 
// MCResourceMonthNames = ['Januar', 'Februar', 'März', 'April',
//                      'Mai', 'Juni', 'Juli', 'August', 'September',
//                      'Oktober', 'November', 'Dezember'];
					    
// English					    
MCValidationRequiredFieldErrorMessage = @"This information is required";
function MCValidationMinLengthErrorMessage(minLength) {return [CPString stringWithFormat:@"Please enter more than %d characters", minLength];};
function MCValidationMaxLengthErrorMessage(maxLength) {return [CPString stringWithFormat:@"Please enter less than %d characters", maxLength];};
function MCValidationGreaterThanErrorMessage(greaterThan) {return [CPString stringWithFormat:@"Please enter a value greater than %d", greaterThan];};
function MCValidationMaxValueErrorMessage(maxValue) {return [CPString stringWithFormat:@"Please enter a value lower than %d", maxValue];};
MCValidationOnlyIntegerErrorMessage = @"Please enter an integer";
MCValidationMinChildrenErrorMessage = @"are too few";
MCValidationMaxChildrenErrorMessage = @"are too many";

MCResourceMonthNames = ['January', 'February', 'March', 'April',
					    'May', 'June', 'July', 'August', 'September',
					    'October', 'November', 'December'];