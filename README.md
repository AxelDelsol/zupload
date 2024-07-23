# Zupload

Design an algorithm that can upload a big file on a cloud storage.
Because we are interested in the algorithm design in this project, an upload will just be a sleep proportional to the data length.

Show usage: `zig build run`

## Step 0 - Motivation

 > Why do I design an upload algorithm when major cloud storage platforms provide an SDK in many languages ?
 
 From my experience with AWS and Microsoft Azure, their SDK are too complex for my needs. I needed less than 10% of the functionalities and it took me longer to learn the library than implement things myself.
 
 More and more applications are run inside containers nowadays. These containers usually have memory and cpu restrictions (e.g `spec.containers[].resources.limits` in Kubernetes) and SDKs usually do not provide memory usage customization.

## Step 1 - Single upload

The simplest step to start with is to ignore the size constraint and upload everything in one call.

It also sets up the base `upload` function as well as timing code.

## Step 2 - Add a memory limit

To deal with the memory limit, we chunk the data into smaller parts and upload them one at a time. This guarantees a bounded memory usage as the upload is sequential.

Notes: We use a `ChunkIterator` to emulate progressive file reading.

## Step 3-4 - Upload in parallel

To speed things up, we move each small upload in their own thread. Running the versions 3 and 4 provide significant speed ups. The algorithm follows: for each memory chunk (from step 2), we split the chunk evenly into `nb_Threads` smaller chunks and upload one in each thread.

At first, I did not use a thread pool. I wanted to learn the `std.Thread` zig API so I spawned threads at each memory chunk upload and joined at the end. Then I used a `std.Thread.Pool` to reuse threads. 

I also added a `std.Thread.WaitGroup`. Without it, tasks would queue up and since arguments are stored in each task, we would break the memory limit constraint. Because we only store slices in this example, it would be fine. In a real file upload, a buffer would be used to read from the file. Since the upload is processed parallel, we would have to copy the buffer as it is not safe to share among threads.

---

When refactoring the code, I came with an owernship problem: who owns the thread pool.

In the first version (`03_memory_limit_thread_pool.zig`), it is considered as an implementation details and is not exposed to the "user" (the main function). It does require to add use a init/deinit pattern to avoid memory leaks.

In the second version (`04_memory_limit_thread_pool2.zig`), it is passed as an argument to the main upload function. It also uses a config struct which emulates keyword arguments.

Retrospectively, I think I should have kept the thread pool as an implementation detail but use a config struct to pass around argument. I will try this approach in my next project.


## Step 5 - Error handling and cancellation

Until now, the upload method could not fail. I think error handling is often neglected in code. There are more and more posts and videos showing how to deal with errors though.

In this project, when a chunk failed to be uploaded, we should stop the upload and report it to the user. The idea is the following: 

* After waiting (with the WaitGroup) for some tasks to finish, we check if we got any errors. If yes, we propagate it so we can stop the upload completely
* The `std.Thread.Pool` API only supports function returning void (you get a compile time error otherwise) so we need to wrap it and use an extra input parameter to store the error.

## Learnings

* `std.Thread.*`zig API
* `std.time.Timer` to measure code
* Iterator implementation in Zig
* Zig build system 
* Command Line Argument using the standard library
* Comptime to add usage and easy code execution