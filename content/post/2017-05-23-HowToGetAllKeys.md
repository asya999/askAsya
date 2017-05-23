+++
title= "How do I get all the names of keys in my documents"
date= "2017-05-23"
categories = ["MongoDB", "Schema", "aggregation"]
slug= "getallkeys"
tags= ["keys","aggregation","schema"]
+++

### Question:

I heard there are new operators in aggregation to extract keys from my documents.  How can I use them to get a list of all key names for all documents in my collection?

### Answer:

There are new expressions available as of [3.4.4][1] - `$objectToArray`, `$arrayToObject` and in 3.5.5 we also get [`$mergeObjects`][3].

[1]: https://docs.mongodb.com/manual/release-notes/3.4/#apr-21-2017
[3]: https://jira.mongodb.org/browse/SERVER-24879

#### Split top level object into array of key value pairs ####

`{"$objectToArray":"$$ROOT"}` will return an array of `{"k":"keyname", "v":<value>}` elements.

```
db.example.findOne()
{
  "_id" : ObjectId("5924aca1530259006a3792ca"),
  "member_id" : "m1",
  "claim_id" : "c1",
  "last_updated" : ISODate("2017-01-01T00:00:00Z"),
  "details" : {
    "foo" : 1
  }
}
db.claims.aggregate({"$limit":1},{"$project":{"o":{"$objectToArray":"$$ROOT"}}}).pretty()
{
  "_id" : ObjectId("5924aca1530259006a3792ca"),
  "o" : [
    {
      "k" : "_id",
      "v" : ObjectId("5924aca1530259006a3792ca")
    },
    {
      "k" : "member_id",
      "v" : "m1"
    },
    {
      "k" : "claim_id",
      "v" : "c1"
    },
    {
      "k" : "last_updated",
      "v" : ISODate("2017-01-01T00:00:00Z")
    },
    {
      "k" : "details",
      "v" : {
        "foo" : 1
      }
    }
  ]
}
```

#### Now what do I do? ####

```
db.claims.aggregate([
  {"$project":{"o":{"$objectToArray":"$$ROOT"}}},
  {"$unwind":"$o"},
  {"$group":{"_id":null, "keys":{"$addToSet":"$o.k"}}}
])
```

#### Are there more efficient ways to do this?  ####

There are other ways to do this, but none of them can escape doing a `$group` stage over all the documents (i.e. with `_id` as a constant, usually null).  But we could avoid `$unwind` stage a couple of different ways.

#####   Using arrays #####

If your documents are more or less uniform, or if the collection isn't too big, you can do this:
```
db.claims.aggregate([
  { "$group": { 
      "_id": null, 
      "keys": { "$addToSet": { 
         "$map": { "input": { "$objectToArray": "$$ROOT" }, "in": "$$this.k" } 
      } } 
  } }, 
  { "$project": { 
      "keys": { "$reduce": { 
          "input": "$keys", 
          "initialValue": [], 
          "in": { "$setUnion": [ "$$this", "$$value" ] } 
       } } 
  } }
])
```

#####   Using `$mergeObjects` #####

3.5 added a new aggregation expression to merge two or more JSON objects, and it's an expression that can be used as an accumulator during `$group` stage.

Basic example: `{"$mergeObjects":[ { "a": 1, "b": "foo"}, { "a": 99, "c": "bar"} ]}` results in `{ "a": 99, "b": "foo", "c": "bar" }`.  When a field exists in more than one object being merged, the last one (going from left to right) "wins".  

More fancy example for schema key analysis:
```
db.claims.aggregate([
  {"$group":{"_id":null, "keys":{"$mergeObjects":"$$ROOT"}}},
  {"$project":{"keys": { "$map": { "input": { "$objectToArray": "$keys" }, "in": "$$this.k" } } } }
])
```

All the above aggregations return the same result:
```
{ "_id" : null, "keys" : [ "details", "_id", "member_id", "last_updated", "claim_id" ] }
```
Though "keys" being a set, the order of fields in the array is not guaranteed to be the same.

Next time I'll show you how you can do more sophisticated schema analysis with aggregation, handling embedded object (i.e. subdocuments) as well as tracking types of values for each key.
