# gvstat

This is a program that collects statistics about a database and makes the result available for analysis as a CSV file.

The most important use of `gvstat` is to establish a baseline by running it continuously, sampling once a minute or so. Then database administrators can use that baseline for capacity planning as usage grows, or for troubleshooting when an application is not working as expected.

## Usage examples

The following command blocks and starts a process that collects database statistics to every 60 seconds:

```
yottadb -run ^gvstat --gatherdb --int 60
```

The statistics are stored in a global variable in the database.

The following command collects statistics once and then returns. It is useful if the collection operation should be triggered by an external timer:

```
yottadb -run ^gvstat --gatherdb --int 0
```

The following command reads the stored database statistics and prints them to stdout as CSV data:

```
yottadb -run ^gvstat --csvdump
```

The CSV data can for example be imported into Excel to be analyzed.

Note that the above commands depend on the YottaDB environment variables to be initialized. This can be done for example by soursing the script `ydb_env_set`.

## Analysing database statistics

The output CSV data record the number of times an event has occured since the last `gvstat` gather operation.

Description of the collected values can be found here: https://docs.yottadb.com/ProgrammersGuide/commands.html#zshow

The following are examples of values that can be of interest when analysing database statistics:

- CAT, CFT. If the ratio CFT/CAT increases from the baseline, it indicates database contention, and an opportunity to improve performance.
- CTN. If CTN increases unexpectedly, it could indicate an increase in workload, or buggy process(es).
- DEX. Frequent database file extensions can cause file system fragmentation. On a production system, set the [extension count](https://docs.yottadb.com/AdminOpsGuide/dbmgmt.html#extension-count) so that the database extends once a month or so. Of course, when ramping up the load on an application, it may extend more often till the load stabilizes.
- DRD, NBR, TBR. The ratio DRD÷(NBR+TBR) tells you what fraction of global buffer fetches required reads from the filesystem. In general, smaller is better, and the ratio can be reduced by increasing the number of global buffers. However, since that takes memory away from the filesystem, the only measure of the right number of global buffers is that which maximizes application throughput.
- DWT, NBW, TBW. The ratio DWT÷(NBW+TBW) is a similar ratio for writes.
- DTA, GET, KIL, ORD, QRY, SET, ZTR. Good baseline data. If the relative ratios of the operations changes materially, it indicates a change in the behavior of the application workload.
- LKF, LKS. The ratio LKF÷(LKF+LKS) is the ratio of lock acquisition attempts that failed. Less is generally better, unless you have an application design in which processes test for locks in a wait loop.
- NR2, NR3, TC3, TC4, TR3, TR4. These are indicators of pathological conflicts. Any consistenly non-zero values should be investigated.
