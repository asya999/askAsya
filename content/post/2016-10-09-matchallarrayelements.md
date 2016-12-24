+++
Categories = ["MongoDB"]
Title= "How to match documents where all array elements match predicate."
Description= "How do I match all documents where all array elements match some predicate?"
Date= "2016-10-09"
Slug= "matchallarrayelements"
Tags= ["schema","query","arrays"]
+++

### Question:

I need to match all documents where every element of an array matches some predicate.  Can that be done?

### Answer:

Yes, the query to do this is actually quite simple to construct.

Remember that when you match an array, MongoDB will "reach inside" the array to compare the predicate to every single 
array element and return the document if the predicate matches at least one of them.  I like to tell MongoDB newbies
to think of arrays as a field that can hold many different values at the same time.  Once you start thinking of
arrays that way, it becomes a lot easier to understand that query like "where A is greater than 50 AND A is less than 10"
is not meaningless if "A" happens to be an array, because different array elements can satisfy the separate parts of
this query.

What that means is that in order to make sure every array element matches some construct, you should negate that construct and then negate the query again.

A simple example can probably help:

Imagine you have this set of documents:
<pre class="prettyprint">
{ "a": [ 1, 2, 3, 4 ] }
{ "a": [ 3, 4, 5, 6 ] }
{ "a": [ 5, 6, 7, 8 ] }
{ "a": [ 1, 2, 3, 4, 5 ] }
</pre>

How do you find all documents where "a" is less than 5?  That's simple, just `db.coll.find({"a":{"$lt":5}})` and we get back (unsurprisingly):
<pre class="prettyprint">
{ "a": [ 1, 2, 3, 4 ] }
{ "a": [ 3, 4, 5, 6 ] }
{ "a": [ 1, 2, 3, 4, 5 ] }
</pre>

This is because at least one element in each of these arrays matches our query predicate.  The third document has no elements that are less than 5.

Now we want to get back only the documents which have *every* element match the same predicate.  Another way of saying "I want every document where each element of array is less than 5" would be "I want every document where none of the elements are greater than or equal to 5".  So we first negate our original query:
````
db.coll.find({"a":{"$gte":5}})
````
and then we negate the entire result:
````
db.coll.find({"$nor":[{"a":{"$gte":5}}]})
````
and as you would expect, the result is:
<pre class="prettyprint">
{ "a": [ 1, 2, 3, 4 ] }
</pre>

When we deal with numbers, it's easy to "negate" a condition, but with arrays, reasoning about "$not" and "$nor" can be tricky so let's try again with strings where we can't use "$gt" and "$lt" so easily.
<pre class="prettyprint">
{ "a" : [ "1", "2", "3", "4" ] }
{ "a" : [ "3", "4", "5", "6" ] }
{ "a" : [ "5", "6", "7", "8" ] }
{ "a" : [ "1", "2", "3", "4", "5" ] }
</pre>

Let's try the same thing we tried above where first we will look for a being one of the set "1","2","3","4" and go from there.
<pre class="prettyprint">
db.coll.find({"a":{"$in":["1","2","3","4"]}})
{ "a" : [ "1", "2", "3", "4" ] }
{ "a" : [ "3", "4", "5", "6" ] }
{ "a" : [ "1", "2", "3", "4", "5" ] }
db.coll.find({"a":{"$nin":["1","2","3","4"]}})
{ "a" : [ "5", "6", "7", "8" ] }
</pre>
What happened?  Did you expect to get back every document which had an element that isn't one of the four in the "$nin" list?  Recall that ["$nin"][2] is the same as saying ["$not"][3] "$in" which is the same as saying "take the set of documents which satisfy the query `{"$in":[<list>]}` and give me the rest of the documents.   So how do we express the query that we want all documents which have an *element* that isn't one of our list?  

Whenever the question (or query) involves an element of an array, there's a good chance that you should be using ["$elemMatch"][1] to express it.   Commonly, we use "$elemMatch" to express that we want the same array element to match multiple conditions in the query predicates, but it's also correct to use it when you are trying to negate the meaning of a query by applying the negation to the element of an array, rather than to the document selection as a whole.

<pre class="prettyprint">
// find me all documents where at least one array element is *not* on our list
db.coll.find({"a":{"$elemMatch":{"$nin":["1","2","3","4"]}}})
{ "a" : [ "1", "2", "3", "4", "5" ] }
{ "a" : [ "3", "4", "5", "6" ] }
{ "a" : [ "5", "6", "7", "8" ] }
// now we negate the entire query
db.coll.find({"$nor":[{"a":{"$elemMatch":{"$nin":["1","2","3","4"]}}}]})
{ "a" : [ "1", "2", "3", "4" ] }
</pre>

Here's another tricky example involving a regular expression - while you can negate a regular expression, you may inadvertantly limit matching to string types only, and when you have mixed type arrays (not recommended, but it happens) that's won't give you desired results.

<pre class="prettyprint">
{ "a" : [ "str1", "str2", "str3", "notstr" ] }
{ "a" : [ "str1", "str2", "str3", "str4" ] }
{ "a" : [ 1, 2, 3, 4, 5 ] }
{ "a" : [ 5, 6, 7, 8, 9 ] }
{ "a" : [ "str1", 0, 10 ] }
</pre>

Say I want to get back just documents that have *all* its "a" elements start with characters "str". Let's look at some queries and their results:
<pre class="prettyprint">
db.coll.find({"a":/^str/})
{ "a" : [ "str1", "str2", "str3", "notstr" ] }
{ "a" : [ "str1", "str2", "str3", "str4" ] }
{ "a" : [ "str1", 0, 10 ] }
db.coll.find({"a":{$not:/^str/}})
{ "a" : [ 1, 2, 3, 4, 5 ] }
{ "a" : [ 5, 6, 7, 8, 9 ] }
// negate regular expression:
db.coll.find({"a":/^(?!str)/})
{ "a" : [ "str1", "str2", "str3", "notstr" ] }
db.coll.find({"a":{$not:/^(?!str)/}})
{ "a" : [ "str1", "str2", "str3", "str4" ] }
{ "a" : [ 1, 2, 3, 4, 5 ] }
{ "a" : [ 5, 6, 7, 8, 9 ] }
{ "a" : [ "str1", 0, 10 ] }
</pre>

Any surprises here?   First, we see that negated regular expression query only matches elements of type string.  We also see that "$not" added to any regex query returns the complement of documents that were returned without "$not" present.  That's not what we need when trying to get all documents with every element that satisfies the predicate.   Let's see if "$elemMatch" gives us what we want:

<pre class="prettyprint">
// note that $elemMatch requires a subdocument so we use ["$regex"][4] rather than / / syntax
db.coll.find({"a":{"$elemMatch":{"$regex":"^str"}}})
{ "a" : [ "str1", "str2", "str3", "notstr" ] }
{ "a" : [ "str1", "str2", "str3", "str4" ] }
{ "a" : [ "str1", 0, 10 ] }
db.coll.find({"a":{"$elemMatch":{$not:/^str/}}})
{ "a" : [ "str1", "str2", "str3", "notstr" ] }
{ "a" : [ 1, 2, 3, 4, 5 ] }
{ "a" : [ 5, 6, 7, 8, 9 ] }
{ "a" : [ "str1", 0, 10 ] }
// bingo!  we got back every document that had something that would NOT match "^str"
// now we just negate that whole query
db.coll.find({"$nor":[{"a":{"$elemMatch":{$not:/^str/}}}]})
{ "a" : [ "str1", "str2", "str3", "str4" ] }
</pre>

Now, let's try it on a more complex document structure with a more complex predicate.
````
{ "b" : [ { "x" : 1, "y" : ISODate("2016-04-09T00:00:00Z") }, { "x" : 2, "y" : ISODate("2016-04-19T00:00:00Z") }, { "x" : 3, "y" : ISODate("2015-12-12T00:00:00Z") } ] }
{ "b" : [ { "x" : 1, "y" : ISODate("2016-02-05T12:00:00Z") }, { "x" : 9, "y" : ISODate("2016-03-01T00:00:00Z") }, { "x" : 5, "y" : ISODate("2015-11-01T00:00:00Z") } ] }
{ "b" : [ { "x" : 3, "y" : ISODate("2016-01-31T12:00:00Z") }, { "x" : 6, "y" : ISODate("2016-03-01T00:00:00Z") }, { "x" : 1, "y" : ISODate("2016-10-01T00:00:00Z") } ] }
{ "b" : [ { "x" : 1, "y" : ISODate("2016-04-09T00:00:00Z") }, { "x" : 2, "y" : ISODate("2016-04-19T00:00:00Z") }, { "x" : 3, "y" : ISODate("2016-09-21T00:00:00Z") } ] }
{ "b" : [ { "x" : 1, "y" : ISODate("2016-04-09T00:00:00Z") }, { "x" : 2, "y" : ISODate("2016-04-19T00:00:00Z") }, { "x" : 3, "y" : ISODate("2016-01-01T00:00:00Z") }, { "x" : 4, "y" : ISODate("2016-01-01T00:00:00Z") } ] }
````

If our predicate was just about "b.x" or just about "b.y" we would use "$elemMatch" rather than dotted notation to run a query just like our first example.  To find all documents where "b.x" is either 1, 2 or 3, we can go through these steps (assume all queries ask in projection just for the field I'm querying by):
````
// find all documents where "b.x" is one of 1,2,3
db.coll.find({"b.x":{$in:[1,2,3]}})
{ "b" : [ { "x" : 1 }, { "x" : 2 }, { "x" : 3 } ] }
{ "b" : [ { "x" : 1 }, { "x" : 9 }, { "x" : 5 } ] }
{ "b" : [ { "x" : 3 }, { "x" : 6 }, { "x" : 1 } ] }
{ "b" : [ { "x" : 1 }, { "x" : 2 }, { "x" : 3 } ] }
{ "b" : [ { "x" : 1 }, { "x" : 2 }, { "x" : 3 }, { "x" : 4 } ] }
````
