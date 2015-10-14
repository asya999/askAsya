+++
Categories = ["MongoDB"]
Tags = ["replication","performance","ops"]
date = "2014-02-20"
title = "Can I use more replica nodes to scale?"
slug = "canreplicashelpscaling"
+++

### Question:

Do replica sets help with read scaling?  If there are more servers to service all my read requests, why wouldn't they be able to service more read requests, or service the same number of read requests faster?

### Answer:

##### Replica Sets.
Replica sets are an awesome feature of MongoDB.  They give you "High Availability" - meaning that when the primary node becomes unavailable (crashes, gets unplugged from the network, gets DOS'ed by another process on the same box) the rest of the nodes will **elect** a new primary and the driver (which your application uses to communicate with MongoDB) will automatically track all nodes and when the primary role changes from one server to another, it will automatically detect to send requests there.
##### Single Master:
MongoDB Replica Sets are a "single master" architecture.  That means that all writes must go to the one primary and from there they are asynchronously replicated to all secondaries.   Your reads also go to the primary, meaning you can always read your own writes.  Your read requests would _never_ be sent to a secondary unless your application *explicitly* requests that the read go somewhere other than the primary, so you would never be getting "stale" data without being aware of it.
##### The questions we have are:
- Should you use secondary reads?   
    + Will they help you handle more reads?
    + Will they help you handle same reads faster?
    + Are there downsides?
- When should you use secondary reads?

Because secondary reads create complexity for your application which now needs to handle (possibly very) stale data and situations where just-made-write is not available for read, I would caution users to be sure that they are getting some benefits from secondary reads.  I’m going to look at possible benefits and discuss whether they are likely to be realized using secondary replica nodes or not. 
##### Will more servers help you handle same reads faster?  
I think the answer for simple operational reads is obviously no.  If a read takes 10μs then it's not likely to take 1/5th of that just because there are five servers - this is a single unit of work.  That's the actual duration of the read.   

##### Will more servers help you handle more reads?
Intuitively, it feels like the answer should be “yes” - but that would only be the case if the reads somehow interfered with each other on the single node.  If they are reading the same “hot” data then they can be working in parallel up to the limit of your CPUs.   So in real life, the answer to whether all your replica nodes together can handle more reads than just your primary is maybe yes and maybe no. Usually no. It all depends on why your single primary cannot handle all of the reads by itself.

My assumption is if your primary can handle all of the reads by itself, then you would have very little reason to even consider reading stale data from a secondary - you gain very little and lose strong consistency of data. There can be some scenarios where reading from a secondary will reduce the latency to the server (not the actual duration of the read) but those are rather specific use cases I’ll point out at the end of the article. 

Okay, so that leaves us with the sad case of a primary that is not able to handle all the reads all by itself. Now we must ask ourselves why it cannot handle all the reads. Depending on the reason why, we can try to predict whether directing some of those reads to secondaries will help the overall situation.

If reads are not handled by primary alone because they are too slow then it doesn't matter why they are too slow - they will be too slow on the secondaries as well. You can try to tune your queries, but it’s more likely that the queries are slow because of underlying root causes... let's look at those 

1. Indexes don't fit in RAM - oops! we know that every replica set member has identical data so if indexes don't fit in RAM on the primary, they don't fit in RAM on the secondary either! 
2. Too much data being scanned (usually because working set doesn't fit in RAM) and the disks are slow - pretty much the same as (1) since the secondaries will have the same limitation 
3. The large number of writes are starving out the reads (i.e. readers have to wait for writers and if there are too many writers when writers yield other writers go and reads can get starved in extreme cases).  But the writes that happen on the primary also have to happen on the secondary!  So moving the readers to the secondary will just starve them on the secondary instead of starving them on the primary.


I know what some of you may be thinking on (3) - you're thinking that all the reads may be starving on the primary but if you split the reads between the primary and the secondary maybe they won't get starved?

Maybe.  But you know what you did when you achieved your read
requirements by splitting the load between the primary and the
secondary?   **You gave up HA**.  Remember, if you can only service the incoming load when all of your nodes are up, then you don't have *any* high availability, as losing a node will basically start starving out some of the incoming requests which means you won't meet your SLAs.

Since replication is for High Availability, it means some of its capacity simply must not be tied up so that it can be “standing by” in case of a failover. If you want to use some extra capacity that you perceive is otherwise going "wasted" to service your every day load, maybe you can do it, as long as you have a very clear understanding that you may have given up some of that High Availability, and I would definitely recommend against that.

One thing I invite you to try is to set up a simple test `mongod` instance where you take some collection with some indexes that all fit in RAM and start up a bunch of multi-threaded clients (from other machines otherwise you'll be testing something else) and have those clients hammer the server with read requests. See how many clients you have to add and how many requests you have to throw at `mongod` before you can't add any more clients requesting more reads without performance of existing reads suffering.  Trying it out will give you an idea of the maximum read throughput that a single node can handle.

Of course, this is not the complete story.  It turns out that there are some excellent use cases for secondary reads, some more common, some less so.

##### The types of reads to route to secondaries #####

There are two types of use cases for reads that you do want to route to secondaries. One I already alluded to: if you have a read heavy system and reads are not super-sensitive to staleness of data but they _are_ super sensitive to overall latency of satisfying a read request, you can realize a big win reading from the nearest member of the replica set rather than the primary.  If your SLA says reads must return in under 100ms but your one way network latency to the primary is 75ms how can you satisfy the SLA from various parts of the world? That's a use case for distributing data all over the world via secondaries in your replica set!  If you have nodes in data centers on different continents (and the PRIMARY near your write source) you can specify read preference of "nearest" and make sure that each read request goes to the node that has the lowest network latency from the requester.

Note that this is _not_ technically "scaling" your read capacity, this is basically taking advantage of replication already having pulled the data over the long network connection and reducing your network latency to the DB.  Don’t forget that if you are relying on reading from “nearest” to meet your SLAs for total round trip to get the data, you have to consider whether your SLAs will still be met if a secondary in a particular region fails.

The second use case is about reads that are not "typical" of your "normal" operational load.  Now, “typical” and “normal” is going to be different for different use cases, but some common examples are things like nightly ETL jobs, ad hoc "historical" or analytical queries, regular backup jobs, or a Hadoop job.  It could also be something else.  The reason you want to isolate this “atypical” load to the secondary is because it will "mess up" your memory-resident data set on the primary!

Imagine you worked very hard to optimize your queries so that indexes are always in RAM and there is just enough RAM left over for the "hot" subset of data to give you excellent performance. You then start running an analytics query and it's pulling _all_ the data from mongo which means your entire data set, hot and cold, now gets pulled into resident memory. Guess what just got evicted to make room for it? Yep, your "normal" data set, or at least a very large portion of it.†

To keep "atypical" jobs from interfering with your "typical" work load, configure the atypical ones to use read preference Secondary. Note that Secondary is different from SecondaryPreferred as the latter will go to the Primary if there is no available Secondary but the former will return an error if there is no Secondary to read from.  Since these jobs are usually not urgent, you’d rather have them wait and retry later than interfere with operational responsiveness of your app anyway.  You can even use ["tags"] [1] to isolate different jobs to specific nodes even further.  

#####Bottom line#####

Make your primary do the work that the application relies on every second.  Make sure that _at least_ one secondary is idle and ready to take over for the primary in case of failure.  Use additional secondaries (_not_ the hot standby one!) for all other needs whether it’s backups, analytical reports, ad hoc queries, ETL, etc.  This way, you know that you can handle the application requirements after a failover just as well as before.

---
†  By the way, this is exactly what happens when you have a query that doesn't have a good index to use - it does a full collection scan - more on that in a future "answer".

[1]: http://docs.mongodb.org/manual/tutorial/configure-replica-set-tag-sets/
