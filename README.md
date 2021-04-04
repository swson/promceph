## promceph
The scripts are for testing Prometheus on using various configurations including compression and erasure coding.

## Dependencies
The script is tested on [Cloudlab](https://www.cloudlab.us/) using the small-lan profile with Ubuntu 20.04.

## Running
* Base: run prombench on a single node with local storage
  1. Clone the repo, first:
     ````
     $ git clone https://github.com/swson/promceph
     ````
  2. Then, run:
     ```
     $ cd promceph
     $ source ./run-prombench-base.sh
     ```
* Ceph-base: run prombench on 3-node with Ceph storage
  1. For each node: 
     1. Clone the repo, first:
        ````
        $ git clone https://github.com/swson/promceph
        ````
     2. Then, run:
        ```
        $ cd promceph
        $ source ./run-prombench-base.sh
        ```
  2. In the first node, e.g., node0 on Cloudlab, run the script for setting up Ceph.
     ```
     $ source ./setup-ceph.sh
     ```
  3. Run the script for running prombench.
     ```
     $ source ./run-prombench-with-ceph.sh
     ```
## Profiling
Use this script to collect storage comsumption and TSDB direcotry structure.
````
while true
do 
  date 2>&1 | tee -a ceph.log
  sudo ceph df 2>&1 tee -a ceph.log
  tree /mnt/cephfs 2>&1 | tee -a ceph.log
  sleep 300
done
````
