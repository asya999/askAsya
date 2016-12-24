---
tags:
  - "schema"
  - "arrays"
  - "performance"
date: "2014-02-13"
title: "Why shouldn't I embed large arrays in my documents?"
description: "The dangers of embedding too much into arrays in documents"
slug: "largeembeddedarrays"
---

+++
Categories = ["MongoDB"]
Title= "Why shouldn't I embed large arrays in my documents?"
Date= "2014-02-13"
Slug= "largeembeddedarrays"
Tags= ["schema","performance","arrays","mongodb"]
+++

### Question:

Why shouldn't I embed large arrays in my documents?  It seems incredibly convenient and intuitive but I've heard there are performance penalties.  What causes them and how do I know if I should avoid using arrays?

### Answer:

Arrays are wonderful when used properly.  When talking about performance, the main reason to be wary of arrays is when they grow without bounds.

Imagine you create a document:
<pre class="prettyprint">
{ user: "Asya",
  email: "asya@mongodb.com",
  twitter: ["@asya999", "@ask-asya"]
}
</pre>

Notice that twitter field is an array.  That's perfectly fine and excellent - we don't want to create a separate collection like we'd have to do in relational model, just because a person might have multiple twitter accounts/handles.  

Now that the document has been created, a certain amount of space has been allocated for it.  If we continue growing the document by adding new fields to it, it will have to be moved and a larger allocation will be made for it because MongoDB dynamically tracks how often documents outgrow their allocation and tries to allocate more space for newly written or moved documents to account for the future growth.

Compare the cost of an update to a document when you can make an in-place change, versus rewriting the entire document somewhere else.  First, instead of just rewriting part of a document "in place" we have to allocate new space for it.  We have to rewrite the entire document, put the space that it used to occupy on the free list so that it can get re-used, and then repoint all the index entries that used to point to the old document location to the new location.  All of this must be done atomically, so your single write suddenly took a bit longer than a few microseconds that it used to take when the document didn't have to move.

Now imagine what happens if you add a new array field to the document representing something that's not naturally bound the way someone's twitter handles or shipping addresses would be bound.  What if we want to embed into this document every time I perform some activity, let's say click on a like button, or make a comment on someone's blog?

First of all, we have to consider why we would want to do such a thing.  Normally, I would advise people to embed things that they always want to get back when they are fetching this document.  The flip side of this is that you don't want to embed things in the document that you don't want to get back with it.

If you embed activity I perform into the document, it'll work great at first because all of my activity is right there and with a single read you can get back everything you might want to show me: "you recently clicked on this and here are your last two comments" but what happens after six months go by and I don't care about things I did a long time ago and you don't want to show them to me unless I specifically go to look for some old activity?

First, you'll end up returning bigger and bigger document and caring about smaller and smaller portion of it.  But you can use projection to only return some of the array, the real pain is that the document on disk will get bigger and it will still all be read even if you're only going to return part of it to the end user, but since my activity is not going to stop as long as I'm active, the document will continue growing and growing.

The most obvious problem with this is eventually you'll hit the 16MB document limit, but that's not at all what you should be concerned about.  A document that continuously grows will incur higher and higher cost every time it has to get relocated on disk, and even if you take steps to mitigate the effects of fragmentation, your writes will overall be unnecessarily long, impacting overall performance of your entire application.

There is one more thing that you can do that will completely kill your application's performance and that's to index this ever-increasing array.  What that means is that every single time the document with this array is relocated, the number of index entries that need to be updated is directly proportional to the number of indexed values in that document, and the bigger the array, the larger that number will be.

I don't want this to scare you from using arrays when they are a good fit for the data model - they are a powerful feature of the document database data model, but like all powerful tools, it needs to be used in the right circumstances and it should be used with care.
