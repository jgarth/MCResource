# MCResource

A library to interact with a RESTful [Rails](http://www.rubyonrails.org) backend in [Cappuccino](http://www.cappuccino.org) extracted from [Cornerstore](http://www.cornerstoreapp.com) - a cloud-based online shop (only available in Germany).

## Short overview

MCResource aims to provide the following features transparently for application developers:

- Model associations (has many / has one / belongs to / nested associations)
- Singleton resources
- Request queues
- Queued requests and sub-requests
- Model validations
- Performance workarounds to keep the browser responsive while working heavy loads (e.g. inserting 1000 objects into an array controller or parsing 1000 JSON dictionaries into objects)

MCResource is designed around asynchronous programming concepts. All loading and saving methods on resources and associations take a delegate and selector argument, and send out KVO-notifications where applicable. Also, convention over configuration was followed, meaning association names and classes and such are usually inferred from their plain english names.

## Example usage

### 1. Setup

Most importantly, MCResource **does not work without type signatures enabled** in Objective-J! So either set the correct preprocessor flag (Preprocessor.Flags.IncludeTypeSignatures) or edit Preprocessor.js to always include type signatures.

First, clone MCResource into your frameworks folder. Then, add the following to your AppController.j:

	// Import MCResource code
	@import "Frameworks/MCResource/MCResource.j"
	
	// Start shared request queue
	[[MCQueue sharedQueue] start];

If you need authentication:

	// Set as delegate to deal with authentication challenges
	[MCHTTPRequest setDelegate:self];

	// And add authorizationCredentials method to the delegate
	- (CPString)authorizationCredentials
	{
		return [MCResource encodeCredentials:@"testuser" password:@"testpassword"];
	}

### 2. Define your model

	@implementation Post : MCResource
	{
		CPString title;
		CPString content;
		CPDate	 publishedAt; // Translates to "published_at" in JSON in- and output.
		BOOL published;
	}

	@end

That's it! You can now use that model as you please. Note that standard attributes like createdAt and updatedAt are automatically provided. 

### 3. Setting up the backend

Obviously you need to setup a rails backend first :) This is covered in so many places I don't want to include a how-to here. 
JSON from Rails 2.x/3 is supported **after you enable ActiveRecord::Base.include\_root\_in\_json** , through default routes. You can also include associations nested in parent resources' JSON if you want to.

For specifics on JSON in-/output see the wiki page.

### 4. Fetching resources from the backend

	- (void)aMethod
	{
		[Post find:nil withDelegate:self andSelector:@selector(didLoadPosts:)];		
	}

	- (void)didLoadPosts:(CPArray)allPosts
	{
		// Use your posts here...
	}

### 5. Saving changes

	- (void)aMethod
	{
		var aPost = [Post new];
		[aPost setValue:@"An example title" forKey:@"title"];
		[aPost setValue:@"It's always hard to come up with example content..." forKey:@"content"];

		[aPost saveWithDelegate:self andSelector:@selector(didSavePost:)];		
	}

	- (void)didSavePost:(Post)aPost
	{
		if([aPost hasErrors])
		{
	        CPLog.debug(@"Errors on post (%@): %@!", aPost, [aPost errors]);
		}
		else
		{
	        CPLog.debug(@"Did save post: %@", aPost);
		}
	}


## Contribute

Please see the wiki page for details on what needs to be done or fixed. Any and all help is greatly appreciated!


## Thanks

This library was heavily inspired by ActiveRecord and some existing cappuccino frameworks like CappuccinoResource.

