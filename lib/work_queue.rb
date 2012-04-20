require 'thread'
require 'monitor'

##
# = Name
# WorkQueue
#
# == Description
# This file contains an implementation of a work queue structure.
#
# == Version
# 2.5.1
#
# == Author
# Miguel Fonseca <contact@miguelfonseca.com>
#
# == Copyright
# Copyright 2012 Miguel Fonseca
#
# == License
# MIT (see LICENSE file)
#

class WorkQueue
  VERSION = "2.5.1"

  ##
  # Creates a new work queue with the desired parameters.
  # It's generally recommended to bound the resources used.
  #
  # ==== Parameter(s)
  # * +max_threads+ - Maximum number of worker threads.
  # * +max_tasks+ - Maximum number of queued tasks.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new 10, nil
  #  wq = WorkQueue.new nil, 20
  #  wq = WorkQueue.new 10, 20
  #
  def initialize(max_threads=nil, max_tasks=nil)
    self.max_threads = max_threads
    self.max_tasks = max_tasks
    @threads = Array.new
    @threads_waiting = 0
    @threads.extend MonitorMixin
    @tasks = Array.new
    @tasks.extend MonitorMixin
    @task_enqueued = @tasks.new_cond
    @task_dequeued = @tasks.new_cond
    @task_completed = @tasks.new_cond
    @tasks_pending = 0
  end

  ##
  # Returns the maximum number of worker threads.
  # This value is set upon initialization and cannot be changed afterwards.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.max_threads		#=> Infinity
  #  wq = WorkQueue.new 1, nil
  #  wq.max_threads		#=> 1
  #
  def max_threads
    @max_threads
  end

  ##
  # Returns the current number of worker threads.
  # This value is just a snapshot, and may change immediately upon returning.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new 1
  #  wq.cur_threads		#=> 0
  #  wq.enqueue_b { ... }
  #  wq.cur_threads		#=> 1
  #
  def cur_threads
    @threads.size
  end

  ##
  # Returns the maximum number of queued tasks.
  # This value is set upon initialization and cannot be changed afterwards.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.max_tasks		#=> Infinity
  #  wq = WorkQueue.new nil, 1
  #  wq.max_tasks		#=> 1
  #
  def max_tasks
    @max_tasks
  end

  ##
  # Returns the current number of queued tasks.
  # This value is just a snapshot, and may change immediately upon returning.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new 1
  #  wq.enqueue_b { ... }
  #  wq.cur_tasks		#=> 0
  #  wq.enqueue_b { ... }
  #  wq.cur_tasks		#=> 1
  #
  def cur_tasks
    @tasks.size
  end

  ##
  # Schedules the given Block for future execution by a worker thread.
  # If there is no space left in the queue, waits until space becomes available.
  #
  # ==== Parameter(s)
  # * +params+ - Parameters passed to the given block.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.enqueue_b("Parameter") { |obj| ... }
  #
  def enqueue_b(*params, &block)
    enqueue block, params
  end

  ##
  # Schedules the given Proc for future execution by a worker thread.
  # If there is no space left in the queue, waits until space becomes available.
  #
  # ==== Parameter(s)
  # * +proc+ - Proc to be executed.
  # * +params+ - Parameters passed to the given proc.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.enqueue_p(Proc.new { |obj| ... }, "Parameter")
  #
  def enqueue_p(proc, *params)
    enqueue proc, params
  end

  ##
  # Waits until the tasks queue is empty and all worker threads have finished.
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.enqueue_b { ... }
  #  wq.join
  #
  def join
    @tasks.synchronize do
      @task_completed.wait_while { @tasks_pending > 0 }
    end
  end

  ##
  # Halt all worker threads immediately, aborting any ongoing tasks.
  # Resets all 
  #
  # ==== Example(s)
  #  wq = WorkQueue.new
  #  wq.enqueue_b { ... }
  #  wq.kill
  #
  def kill
    @tasks.synchronize do
      @threads.synchronize do
        @threads.each { |thread| thread.exit }
        @threads.clear
        @threads_waiting = 0
      end
      @tasks.clear
      @tasks_pending = 0
      @task_dequeued.broadcast
      @task_completed.broadcast
    end
  end

  private

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
  # Schedules the given Proc for future execution by a worker thread.
  #
  def enqueue(proc, params)
    @tasks.synchronize do
      @task_dequeued.wait_until { @tasks.size < @max_tasks }
      @tasks << [proc, params]
      @tasks_pending += 1
      @task_enqueued.signal
    end
    spawn_thread
  end

  ##
  # Enrolls a new worker thread. The request is only carried out if necessary.
  #
  def spawn_thread
    @tasks.synchronize do
      @threads.synchronize do
        if @threads.size < @max_threads && @threads_waiting <= 0 && @tasks.size > 0
          @threads << Thread.new { run }
        end
      end
    end
  end

  ##
  # Repeatedly process the tasks queue.
  #
  def run
    begin
      loop do
        proc, params = dequeue
        begin
          proc.call(*params)
        rescue Exception => e
          # Suppress Exception
        end
        conclude
      end
    ensure
      @threads.synchronize do
        @threads.delete Thread.current
      end
    end
  end

  ##
  # Retrieves a task from the queue.
  #
  def dequeue
    @tasks.synchronize do
      @threads_waiting += 1
      @task_enqueued.wait_while { @tasks.empty? }
      @threads_waiting -= 1
      task = @tasks.shift
      @task_dequeued.signal
      return task
    end
  end

  ##
  # Wind up a task execution.
  #
  def conclude
    @tasks.synchronize do
      @tasks_pending -= 1
      @task_completed.signal
    end
  end
end