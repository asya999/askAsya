Title: How to Model Dynamic Attributes
Date: 2014-04-15 16:31 
Type: post
Published: true
Slug: :DynamicAttributes
Tags: schema,modeling,indexes,mongodb,arrays

### Question:

I've heard that MongoDB can be effectively used to model "dynamic attributes" - where you don't know up front all the different attributes and not all attributes apply to all items.  Can you describe how that can be done, and in particular how it can be effectively indexed?

### Answer:

##### The problem:

Imagine you are building an e-commerce site and you aspire to be as big as amazon.com some day, which means you will be selling many different types of products.  It's easy to see that there will be sets of attributes that will only apply to some of the products you sell.

Product document may look like this:

    {
      SKU: "XRD12349",
      type: "book",
      title: "MongoDB, The Definitive Guide",
      ISBN: "xxx",
      author: [ "Kristina Chodorow", "Mike Dieroff"],
      genre: ["computing", "databases"]
    }
or this:
 
    {
      SKU: "Y32944EW",
      type: "shoes",
      manufacturer: "ShoesForAll",
      color: "blue",
      style: "comfort",
      size: "7B"
    }
    
You can see how it would be extremely challenging to manage a collection that has an incredibly wide variety of document "shapes".  Now, while some people call MongoDB "schemaless" I am not a fan of this designation.  The schema of each document is defined by the document itself.  To be able to build a robust applications you need to decide what the schema of the documents will be, otherwise your application will spend as much time examining the documents to learn their schema as providing actual functionality.

##### Possible solutions:

One way to index the attributes you want to be able to search by is by creating an index on each such attribute in a schema like the one above.  This is not practical, even if you use ["sparse" indexes](http://docs.mongodb.org/manual/core/index-sparse/) (since many attributes will be set only on a small subset of the products), because you may end up with dozens, if not hundreds of indexes.  In addition, every time a new attribute is introduced, a new index has to be added on the collection.  Not very practical.

The other solution, which is a nice generalization of storing attributes which are numerous and not known up-front, is to use an array of key-value pairs.

Our two sample documents might then become:

    {
      SKU: "XRD12349",
      type: "book",
      attr: [
          { "k": "title", 
            "v": "MongoDB, The Definitive Guide, 1st Edition"
          },
          { "k": "ISBN",
            "v": "xxx"
          },
          { "k": "author",
            "v": "Kristina Chodorow"
          },
          { "k": "author",
            "v": "Mike Dieroff"
          },
          { "k": "genre",
            "v": ["computing", "databases"] 
          }
      ]
    }

and 
 
    {
      SKU: "Y32944EW",
      type: "shoes",
      attr: [
          { "k": "manufacturer", 
            "v": "ShoesForAll",
          },
          { "k": "color", 
            "v": "blue",
          },
          { "k": "style", 
            "v": "comfort",
          },
          { "k": "size", 
            "v": "7B"
          }
      ]
    }

Note that for an attribute that can have multiple values you have a choice of storing it as an array in a single "key" or you can repeat keys that can have more than one value.

Now we can index all of these attribute values with the following: 

<pre class="prettyprint lang-js">
PRIMARY(2.6.0) > db.products.ensureIndex( { "attr.k":1, "attr.v":1 } )
</pre>

Let's take a look at how the queries will execute and use the index by using the "explain()" helper in MongoDB shell.  When filtering based on attribute key-value pair, remember to use the `$elemMatch` operator to indicate that both conditions must be satisfied by the same element of the array.

<pre class="prettyprint lang-js">
PRIMARY(2.6.0) > db.products.find( 
                                { "attr": { "$elemMatch" : { "k":"size", "v":"8B" } }
                     } ).explain()
{
	"cursor" : "BtreeCursor attr.k_1_attr.v_1",
	"isMultiKey" : true,
	"n" : 104,
	"nscannedObjects" : 104,
	"nscanned" : 104,
	"nscannedObjectsAllPlans" : 104,
	"nscannedAllPlans" : 104,
	"scanAndOrder" : false,
	"indexOnly" : false,
	"nYields" : 0,
	"nChunkSkips" : 0,
	"millis" : 2,
	"indexBounds" : {
		"attr.k" : [
			[
				"size",
				"size"
			]
		],
		"attr.v" : [
			[
				"8B",
				"8B"
			]
		]
	},
	"server" : "asyasmacbook.local:27017",
	"filterSet" : false
}
</pre>

<pre class="prettyprint lang-js">
PRIMARY(2.6.0) > db.products.find(
                  { "attr" :  { "$elemMatch" : { "k":"color", "v":"blue"}}
              } ).explain()
{
	"cursor" : "BtreeCursor attr.k_1_attr.v_1",
	"isMultiKey" : true,
	"n" : 98,
	"nscannedObjects" : 98,
	"nscanned" : 98,
	"nscannedObjectsAllPlans" : 98,
	"nscannedAllPlans" : 98,
	"scanAndOrder" : false,
	"indexOnly" : false,
	"nYields" : 0,
	"nChunkSkips" : 0,
	"millis" : 0,
	"indexBounds" : {
		"attr.k" : [
			[
				"color",
				"color"
			]
		],
		"attr.v" : [
			[
				"blue",
				"blue"
			]
		]
	},
	"server" : "asyasmacbook.local:27017",
	"filterSet" : false
}
</pre>

Now I'll use both criteria, and I'll add another one for attribute "style" - since I want to match only when *all* are true (rather than when any is true) I will use the `$all` operator.  Passing "true" as an argument to explain will show all considered plans and not just the winning plan.

<pre class="prettyprint lang-js">
PRIMARY(2.6.0) > db.products.find( { "attr" : { "$all" : [ 
                    { "$elemMatch" : { "k":"style", "v":"comfort" } }, 
                    { "$elemMatch" : { "k":"color", "v":"blue" } },
                    { "$elemMatch" : { "k":"size", "v":"8B" } } 
                  ] } } ).explain(true)
{
	"cursor" : "BtreeCursor attr.k_1_attr.v_1",
	"isMultiKey" : true,
	"n" : 1,
	"nscannedObjects" : 98,
	"nscanned" : 98,
	"nscannedObjectsAllPlans" : 296,
	"nscannedAllPlans" : 298,
	"scanAndOrder" : false,
	"indexOnly" : false,
	"nYields" : 2,
	"nChunkSkips" : 0,
	"millis" : 1,
	"indexBounds" : {
		"attr.k" : [
			[
				"color",
				"color"
			]
		],
		"attr.v" : [
			[
				"blue",
				"blue"
			]
		]
	},
	"allPlans" : [
		{
			"cursor" : "BtreeCursor attr.k_1_attr.v_1",
			"isMultiKey" : true,
			"n" : 1,
			"nscannedObjects" : 98,
			"nscanned" : 98,
			"scanAndOrder" : false,
			"indexOnly" : false,
			"nChunkSkips" : 0,
			"indexBounds" : {
				"attributes.name" : [
					[
						"color",
						"color"
					]
				],
				"attributes.value" : [
					[
						"blue",
						"blue"
					]
				]
			}
		},
		{
			"cursor" : "BtreeCursor attr.k_1_attr.v_1",
			"isMultiKey" : true,
			"n" : 1,
			"nscannedObjects" : 99,
			"nscanned" : 100,
			"scanAndOrder" : false,
			"indexOnly" : false,
			"nChunkSkips" : 0,
			"indexBounds" : {
				"attributes.name" : [
					[
						"style",
						"style"
					]
				],
				"attributes.value" : [
					[
						"comfort",
						"comfort"
					]
				]
			}
		},
		{
			"cursor" : "BtreeCursor attr.k_1_attr.v_1",
			"isMultiKey" : true,
			"n" : 1,
			"nscannedObjects" : 99,
			"nscanned" : 100,
			"scanAndOrder" : false,
			"indexOnly" : false,
			"nChunkSkips" : 0,
			"indexBounds" : {
				"attributes.name" : [
					[
						"size",
						"size"
					]
				],
				"attributes.value" : [
					[
						"8B",
						"8B"
					]
				]
			}
		}
	],
	"server" : "asyasmacbook.local:27017",
	"filterSet" : false,
	"stats" : {
		"type" : "KEEP_MUTATIONS",
		"works" : 100,
		"yields" : 2,
		"unyields" : 2,
		"invalidates" : 0,
		"advanced" : 1,
		"needTime" : 97,
		"needFetch" : 0,
		"isEOF" : 1,
		"children" : [
			{
				"type" : "FETCH",
				"works" : 99,
				"yields" : 2,
				"unyields" : 2,
				"invalidates" : 0,
				"advanced" : 1,
				"needTime" : 97,
				"needFetch" : 0,
				"isEOF" : 1,
				"alreadyHasObj" : 0,
				"forcedFetches" : 0,
				"matchTested" : 1,
				"children" : [
					{
						"type" : "IXSCAN",
						"works" : 98,
						"yields" : 2,
						"unyields" : 2,
						"invalidates" : 0,
						"advanced" : 98,
						"needTime" : 0,
						"needFetch" : 0,
						"isEOF" : 1,
						"keyPattern" : "{ attr.k: 1.0, attr.v: 1.0 }",
						"boundsVerbose" : "field #0['attr.k']: [\"color\", \"color\"], field #1['attr.v']: [\"blue\", \"blue\"]",
						"isMultiKey" : 1,
						"yieldMovedCursor" : 0,
						"dupsTested" : 98,
						"dupsDropped" : 0,
						"seenInvalidated" : 0,
						"matchTested" : 0,
						"keysExamined" : 98,
						"children" : [ ]
					}
				]
			}
		]
	}
}
</pre>

What does this mean?   If we look at `allPlans` we see that the optimizer tried our attribute index separately (but in parallel) with each of the clauses inside the $all array.  The winning plan was for "color" attribute because it turned out to be the most selective.

In MongoDB 2.4 this was not possible and unfortunately the optimizer would use the index for the first clause of the `$all` expression.  If it happened to have low selectivity, then you didn't get as good performance as you might have, had you ordered your conditions differently.  In 2.6 the order of expressions inside `$all` does not make a difference as the one that's most selective will be the one used by the query optimizer.

Depending on how you need to query your attributes, there are different ways of structuring the attribute array.  You can use key-value pairs as I showed, you can use the attribute name as the key value, or you can even store a single string value "attrname::attrvalue" - best thing is to take a look at the types of queries and updates you will be running and try it different ways, benchmark which one works best and use that one.