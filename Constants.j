MCAssociationDidLoadNotificationName = "MCAssociationDidLoadNotification"
MCHTTPRequestDidChangeProgressNotificationName = "MCHTTPRequestDidChangeProgressNotification";
MCHTTPRequestDidFinishNotificationName = "MCHTTPRequestDidFinishNotification";

// Generates a 10-figure pseudorandom string
MCGenerateShortRandom = function() {
    return (new Date().getMilliseconds() + Math.random() * 1e6).toString().substring(10);
};

// Messages & Strings

// English					    
MCValidationRequiredFieldErrorMessage = @"This information is required";
function MCValidationMinLengthErrorMessage(minLength) {return [CPString stringWithFormat:@"Please enter more than %d characters", minLength];};
function MCValidationMaxLengthErrorMessage(maxLength) {return [CPString stringWithFormat:@"Please enter less than %d characters", maxLength];};
function MCValidationGreaterThanErrorMessage(greaterThan) {return [CPString stringWithFormat:@"Please enter a value greater than %d", greaterThan];};
function MCValidationMaxValueErrorMessage(maxValue) {return [CPString stringWithFormat:@"Please enter a value lower than %d", maxValue];};
MCValidationOnlyIntegerErrorMessage = @"Please enter an integer";
MCValidationMinChildrenErrorMessage = @"are too few";
MCValidationMaxChildrenErrorMessage = @"are too many";
MCResourceGeneralErrorMessage = @"We're sorry, but there was an error!"
MCResourceGeneralErrorDetailedMessage = @"An error was encountered performing one or more requests. Please see the error console for details."

MCResourceMonthNames = ['January', 'February', 'March', 'April',
					    'May', 'June', 'July', 'August', 'September',
					    'October', 'November', 'December'];