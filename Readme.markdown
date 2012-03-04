# MCResource

A library to interact with a RESTful [Rails](rubyonrails.org) backend in [Cappuccino](cappuccino.org) extracted from [Cornerstore](www.cornerstoreapp.com) - a cloud-based online shop (only available in Germany).

## Short overview

MCResource aims to provide the following features transparently for application developers:

- Model associations (has many / has one / belongs to / nested associations)
- Singleton resources
- Request queues
- Queued requests and sub-requests
- Model validations
- Performance workarounds to keep the browser responsive while working heavy loads (e.g. inserting 1000 objects into an array controller or parsing 1000 JSON dictionaries into objects)

MCResource is designed around asynchronous programming concepts. All loading and saving methods on resources and associations take a delegate and selector argument, and send out KVO-notifications where applicable. Also, convention over configuration was followed, meaning association names and classes and such are usually inferred from their plain english names.

## Simple example

### 1. Setup

	// Import MCResource code
	@import "Frameworks/MCResource/MCResource.j"
	
	// Start shared request queue
	[[MCQueue sharedQueue] start];

If you need authentication:

	// Set as delegate to deal with authentication challenges
	[MCHTTPRequest setDelegate:self];

	// And add authorizationCredentials method
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
Out-of-the box JSON from Rails 2.x/3 is supported, through default routes. You can also include associations nested in parent resources' JSON if you want to.

MCResource expects the backend to act like this:

Class "Post", request to GET /posts should yield:

	[
		{
			"post":
			{
				"title": "a post",
				"content": "some content",
				"rating":
				{
					"aggregate": 2.5, 
					"some_other_method": 3.1
				},
			"created_at": "2012-01-12T17:30:58+01:00",
			"updated_at": "2012-01-12T17:30:58+01:00",
			"published_at": "2012-01-12T17:30:58+01:00",
			"id": 1,
			}
		},
		{
			"post":
			{
				"title": "another post",
				"content": "some more content",
				"rating":
				{
					"aggregate": 1.9, 
					"some_other_method": null
				},
				"created_at": "2012-01-12T17:30:58+01:00",
				"updated_at": "2012-01-12T17:30:58+01:00",
				"published_at": "2012-01-12T17:30:58+01:00",
				"id": 2,
			}
		},
	]

JSON for saving is constructed using FormData objects (transparent for rails if you just use the _params_ hash).
This is really convenient if you decide to upload files, MCResource does not care. Also, some work is done by the browser instead of its JS engine.

Saving a comment attached to a post via hasMany-Association will create a PUT request to /posts/1/comments/3

	------WebKitFormBoundaryAFOJVz3sALr2LK78
	Content-Disposition: form-data; name="comment[title]"

	A changed title.
	------WebKitFormBoundaryBXIxhz5Rl8Qsjwtj
	Content-Disposition: form-data; name="comment[content]"

	Some changed content.
	It's nice to debug with WebKit's inspector
	------WebKitFormBoundaryBXIxhz5Rl8Qsjwtj
	Content-Disposition: form-data; name="variant[rating][aggregate]"

	6.9
	------WebKitFormBoundaryBXIxhz5Rl8Qsjwtj--

and will arrive in Rails like this:

	Parameters: {"post_id"=>"1", "id"=>"3", "comment"=>{"title"=>"A changed title.", "content"=>"Some changed content.", "rating" => {"aggregate" => 6.9}}}

### 4. Fetching resources from the backend

	- (void)aMethod
	{
		[Post findWithDelegate:self andSelector:@selector(didLoadPosts:)];		
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
			// React to errors if you need to.
		}
		else
		{
			// Do something if you need to.
		}
	}

## Some more advanced examples

### Associations

Let's stick to the established example of posts and comments. You might do the following:

#### Models
	@implementation Post : MCResource
	{
		CPString title;
		CPString content;
		BOOL published;
	}

	+ (void)initialize
	{
		[self hasMany:@"comments"];
		[self hasOne:@"author"];
	}
	@end

	@implementation Comment : MCResource
	{
		CPString content;
	}

	+ (void)initialize
	{
		[self hasMany:@"ratings"];
		[self belongsTo:@"post"]; // Gives the ability to call [[aComment associationForName:@"post"] associatedObject] 
								  // even if that Comment was not loaded through the association on Post;
	}
	@end
	
#### Controller
	var aTextField;

	- (void)someMethod
	{
		aTextField = [CPTextField labelWithTitle:@""];
	}
	
	- (void)postsDidLoad:(CPArray)posts
	{
		[aTextField bind:CPValueBinding toObject:aPost withKeyPath:@"comments.@count" options:nil];
	}


You can pass an options CPDictionary to hasMany:/hasOne: with the following keys supported at this time: 	


	MCResourceAssociationObjectClassKey // Set a custom class if it cannot be inferred from the association name
	MCResourceAssociationAutosaveKey    // YES will save the association along everytime the owning resource is saved
	MCResourceAssociationShallowKey     // YES will construct the resource URL directly under the application root 
	MCResourceAssociationNestedOnlyKey  // YES will mark the association as being "nested" under its parent resource's JSON in/output
	MCResourceAssociationSortDescriptorsKey // Array of sort descriptors for has many associations;



## Contribute

Please see the wiki page for details on what needs to be done or fixed. Any and all help is greatly appreciated!


## Thanks

This library was heavily inspired by ActiveRecord and some existing cappuccino frameworks like CappuccinoResource.

