##
# = Name
# WorkQueue
#
# == Description
# This file contains an implementation of a work queue structure.
#
# == Version
# 2.0.0.beta
#
# == Author
# Miguel Fonseca <fmmfonseca@gmail.com>
#
# == Copyright
# Copyright 2009-2011 Miguel Fonseca
#
# == License
# MIT (see LICENSE file)
#

require 'thread'
require 'monitor'

##
# = WorkQueue
#
# == Description
# A tunable work queue, designed to coordinate work between a producer and a pool of worker threads.
#
# == Usage
#  wq = WorkQueue.new
#  wq.enqueue_b { puts "Hello from the WorkQueue" }
#  wq.join
#
class WorkQueue
    
    VERSION = "2.0.0.beta"
    
    ##
    # Creates a new work queue with the desired parameters.
    #
    #  wq = WorkQueue.new(5,10,20)
    #
    def initialize(max_threads=nil, max_tasks=nil)
        self.max_threads = max_threads
        self.max_tasks = max_tasks
        @threads = Array.new
        @threads.extend(MonitorMixin)
        @threads_waiting = 0
        @tasks = Array.new
        @tasks.extend(MonitorMixin)
        @task_enqueued = @tasks.new_cond
        @task_completed = @tasks.new_cond
        @cur_tasks = 0
    end
    
    ##
    # Returns the maximum number of worker threads.
    # This value is set upon initialization and cannot be changed afterwards.
    #
    #  wq = WorkQueue.new()
    #  wq.max_threads		#=> Infinity
    #  wq = WorkQueue.new(1)
    #  wq.max_threads		#=> 1
    #
    def max_threads
        @max_threads
    end
    
    ##
    # Returns the current number of worker threads.
    # This value is just a snapshot, and may change immediately upon returning.
    #
    #  wq = WorkQueue.new(10)
    #  wq.cur_threads		#=> 0
    #  wq.enqueue_b {}
    #  wq.cur_threads		#=> 1
    #
    def cur_threads
        @threads.size
    end
    
    ##
    # Returns the maximum number of queued tasks.
    # This value is set upon initialization and cannot be changed afterwards.
    #
    #  wq = WorkQueue.new()
    #  wq.max_tasks		#=> Infinity
    #  wq = WorkQueue.new(nil,1)
    #  wq.max_tasks		#=> 1
    #
    def max_tasks
        @max_tasks
    end
    
    ##
    # Returns the current number of active tasks.
    # This value is just a snapshot, and may change immediately upon returning.
    #
    #  wq = WorkQueue.new(1)
    #  wq.enqueue_b { sleep(1) }
    #  wq.cur_tasks		#=> 0
    #  wq.enqueue_b {}
    #  wq.cur_tasks		#=> 1
    #
    def cur_tasks
        @cur_tasks
    end
    
    ##
    # Schedules the given Proc for future execution by a worker thread.
    # If there is no space left in the queue, waits until space becomes available.
    #
    #  wq = WorkQueue.new(1)
    #  wq.enqueue_p(Proc.new {})
    #
    def enqueue_p(proc, *args)
        enqueue(proc, args) 
    end
    
    ##
    # Schedules the given Block for future execution by a worker thread.
    # If there is no space left in the queue, waits until space becomes available.
    #
    #  wq = WorkQueue.new(1)
    #  wq.enqueue_b {}
    #
    def enqueue_b(*args, &block)
       enqueue(block, args) 
    end
    
    ##
    # Waits until the tasks queue is empty and all worker threads have finished.
    #
    #  wq = WorkQueue.new(1)
    #  wq.enqueue_b { sleep(1) }
    #  wq.join
    #
    def join
        @tasks.synchronize do
            @task_completed.wait_while { cur_tasks > 0 }
        end
    end
    
    ##
    # Stops all worker threads immediately, aborting any ongoing tasks.
    #
    #  wq = WorkQueue.new(1)
    #  wq.enqueue_b { sleep(1) }
    #  wq.kill
    #
    def kill
        @tasks.synchronize do
            @threads.dup.each { |thread| thread.exit.join }
            @threds.clear
            @threads_waiting = 0
            @tasks.clear
            @cur_tasks = 0
        end
    end
    
    private
    
    ##
    # Generic
    #
    def enqueue(proc, args)
        @tasks.synchronize do
            @task_completed.wait_while { cur_tasks >= max_tasks }
            @tasks << [proc, args]
            @cur_tasks += 1
            @task_enqueued.signal
            spawn_thread
        end
    end
    
    ##
    # Sets the maximum number of worker threads.
    #
    def max_threads=(value)
        raise ArgumentError, "the maximum number of threads must be positive" if value and value <= 0
        @max_threads = value || 1.0/0
    end
    
    ##
    # Sets the maximum number of queued tasks.
    #
    def max_tasks=(value)
        raise ArgumentError, "the maximum number of tasks must be positive" if value and value <= 0
        @max_tasks = value || 1.0/0
    end
    
    ##
    # Enrolls a new worker thread.
    # The request is only carried out if necessary.
    #
    def spawn_thread
        @threads.synchronize do
            if cur_threads < max_threads and @threads_waiting <= 0 and @tasks.size > 0
                @threads << Thread.new do
                    begin
                        work
                    ensure
                        @threads.synchronize do
                            @threads.delete(Thread.current)
                        end
                    end
                end
            end
        end
    end
    
    
    ##
    # Repeatedly process the tasks queue.
    #
    def work
       loop do 
            begin
                proc, args = @tasks.synchronize do
                    @threads_waiting += 1
                    @task_enqueued.wait_while { @tasks.size <= 0 }
                    @threads_waiting -= 1
                    @tasks.shift
                end
                proc.call(*args)
            rescue Exception => e
                # Suppress Exception
            ensure
                @tasks.synchronize do
                    @cur_tasks -= 1
                    @task_completed.broadcast
                end
            end
       end
    end
    
end