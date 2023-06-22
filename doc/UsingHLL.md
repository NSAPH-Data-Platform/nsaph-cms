# Using HyperLogLog (HLL) hashes for count approximations

HyperLogLog is an algorithm to estimate cardinality in extremely 
large datasets using little memory and time.
This simple but extremely powerful algorithm aims to answer a question: 
How to estimate the number of unique values (aka cardinality) 
within a very large dataset? This question is called Count-distinct 
problem in Computer Science or Cardinality Estimation Problem 
in Applied Mathematics. We will call it Cardinality Estimation 
Problem in this article because it sounds more impressive.

Background info: see 
[HyperLogLog: A Simple but Powerful Algorithm for Data Scientists](https://towardsdatascience.com/hyperloglog-a-simple-but-powerful-algorithm-for-data-scientists-aed50fe47869) 

Also [Wikipedia](https://en.wikipedia.org/wiki/HyperLogLog)

We use 
[PostgreSQL HLL Extension](https://github.com/citusdata/postgresql-hll) 
to facilitate approximate **COUNT DISTINCT** queries. For example, to estimate
a number of beneficiaries that ever lived in a certain zip code, or a group of
zip codes.