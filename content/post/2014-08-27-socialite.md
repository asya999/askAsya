+++
Categories = ["MongoDB"]
Title= "Social Status Feed in MongoDB"
Date= "2014-08-27"
Slug= "socialstatusfeed"
Tags= ["schema","modeling","indexes","social"]
+++

### Socialite

At MongoDBWorld, my colleague Darren Wood and I gave [three back-to-back presentations][1] about an [open source project called Socialite][2] which is a reference architecture implementation of a social status feed service.  Darren was the one who wrote the bulk of the source code and I installed and ran extensive performance tests in different configurations to determine how the different schema and indexing options scale and to get an understanding of the resources required for various sizes and distributions of workloads.

The recordings and slides are [now available on MongoDB website][1], if you want to jump in and watch, but since we had to race through the material,  I'm going to blog about some of the more interesting questions it raised, mainly about schema design, indexing and sharding choices and how to benchmark a large, complex application.

There were three talks because there was a large amount of material and because there are several rather complex orthogonal topics when considering a social status feed:

1. How will you store the content long term
2. How will you store the user graph
3. How will you serve up the status feed for a particular user when they log in

The last one is probably most interesting in that it has the most possible approaches, though as it turns out, some have very big downsides and would only be appropriate to pretty small systems.  User graph is fascinating because of its relevance to so many different domains beyond social networks of friends.  And performance considerations are complex and interdependent among all of them.   For each of the three talks we had two parts - Darren discussed possible schema designs, indexing considerations and if appropriate sharding implications, and I walked through the actual testing I did and whether each option held up as expected.  

Unfortunately even across three sessions we were quite time limited, so all the various bits of material we have that didn't make it into these presentations will end up in one of several spots:

- here
- [mongodb.org blog][4]
- advanced schema design class at [MongoDB University][3] (coming soon!)

I get a lot of questions about schema design, and social data is both popular and very doable in MongoDB but the naive approach is usually bound to meet with failure, so the schema needs to be carefully considered with an eye towards the following two most important considerations:

- enduser latency
- linear scaling

As we said during the presentations, for every single decision, we had to consider as the most important goals keeping the user's first read latency as low and constant as possible (or else they would leave and go somewhere else) and our ability to scale any design we had linearly with scaling.  That meant that every single workload had to be scalable or partitionable in a way that would isolate the workload to a subset of data.  

Over the next few months as I write up different parts of the system, and consider the schema, indexes and possible shard data distribution, you will see me return to these two litmus tests again and again.   In order to have highest chance of success at large scale any option that hinders one of these goals should be out of the running.



[1]: http://www.mongodb.com/search/google/socialite?query=socialite&cx=017213726194841070573%3Ak6mpwzohlje&cof=FORID%3A9&sitesearch=
[2]: http://github.com/10gen-labs/socialite
[3]: https://univerity.mongodb.com
[4]: http://blog.mongodb.org
